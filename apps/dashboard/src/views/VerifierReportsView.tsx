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

export function VerifierReportsView({ data }: { data: DashboardData }) {
  const [query, setQuery] = useState("");
  const [status, setStatus] = useState<DashboardStatus | "all">("all");

  const reports = useMemo(() => {
    const statusFiltered =
      status === "all" ? data.verifierReports : data.verifierReports.filter((report) => report.status === status);
    return searchRecords(statusFiltered, query);
  }, [data.verifierReports, query, status]);

  return (
    <div className="view-stack">
      <SectionHeader
        eyebrow="verifier"
        title="Verifier reports"
        detail="Fixture verifier outputs with report identity, reason codes, and deterministic check counts."
        action={
          <div className="filter-row">
            <label className="search-box">
              <Search size={16} aria-hidden="true" />
              <input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search reports" />
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
        {reports.length > 0 ? (
          <div className="table-scroll">
            <table>
              <thead>
                <tr>
                  <th>Status</th>
                  <th>Report</th>
                  <th>Observation / rootfield</th>
                  <th>Policy</th>
                  <th>Checks</th>
                  <th>Provenance</th>
                </tr>
              </thead>
              <tbody>
                {reports.map((report) => (
                  <tr key={report.reportId}>
                    <td>
                      <StatusBadge status={report.status} />
                    </td>
                    <td>
                      <div className="cell-stack">
                        <HashValue value={report.reportId} label="report id" />
                        <small>
                          hash <HashValue value={report.reportHash} trim="short" />
                        </small>
                      </div>
                    </td>
                    <td>
                      <div className="cell-stack">
                        <span>
                          obs <HashValue value={report.observationId} trim="short" />
                        </span>
                        <span>
                          root <HashValue value={report.rootfieldId} trim="short" />
                        </span>
                      </div>
                    </td>
                    <td>
                      <div className="cell-stack">
                        <span>{report.resolverPolicyId}</span>
                        <small>spec {report.verifierSpecVersion}</small>
                      </div>
                    </td>
                    <td>
                      <div className="cell-stack">
                        <span>
                          {report.checksPassed}/{report.checksTotal}
                        </span>
                        <small>{report.reasonCodes.join(", ") || "none"}</small>
                      </div>
                    </td>
                    <td>
                      <ProvenanceLine provenance={report.provenance} lastUpdated={report.lastUpdated} />
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <EmptyState
            title="No verifier reports match"
            detail="Clear search filters or add generated verifier reports to the fixture boundary."
          />
        )}
      </section>
    </div>
  );
}
