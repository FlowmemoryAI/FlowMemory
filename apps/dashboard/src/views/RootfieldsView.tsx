import { useMemo, useState } from "react";
import { Search } from "lucide-react";
import { EmptyState } from "../components/EmptyState";
import { HashValue } from "../components/HashValue";
import { ProvenanceLine } from "../components/ProvenanceLine";
import { SectionHeader } from "../components/SectionHeader";
import { StatusBadge } from "../components/StatusBadge";
import { searchRecords } from "../data/selectors";
import type { DashboardData } from "../data/types";

export function RootfieldsView({ data }: { data: DashboardData }) {
  const [query, setQuery] = useState("");
  const rootfields = useMemo(() => searchRecords(data.rootfields, query), [data.rootfields, query]);

  return (
    <div className="view-stack">
      <SectionHeader
        eyebrow="rootfield registry"
        title="Rootfields"
        detail="Fixture registry state for namespaces, compact commitments, and latest local roots."
        action={
          <label className="search-box">
            <Search size={16} aria-hidden="true" />
            <input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search rootfields" />
          </label>
        }
      />

      {rootfields.length > 0 ? (
        <section className="rootfield-grid">
          {rootfields.map((rootfield) => (
            <article className="rootfield-tile" key={rootfield.rootfieldId}>
              <div className="tile-heading">
                <StatusBadge status={rootfield.status} />
                <HashValue value={rootfield.rootfieldId} label="rootfield id" />
              </div>
              <dl className="definition-grid">
                <div>
                  <dt>owner</dt>
                  <dd>
                    <HashValue value={rootfield.owner} trim="short" />
                  </dd>
                </div>
                <div>
                  <dt>latest root</dt>
                  <dd>
                    <HashValue value={rootfield.latestRoot} />
                  </dd>
                </div>
                <div>
                  <dt>schema hash</dt>
                  <dd>
                    <HashValue value={rootfield.schemaHash} />
                  </dd>
                </div>
                <div>
                  <dt>metadata hash</dt>
                  <dd>
                    <HashValue value={rootfield.metadataHash} />
                  </dd>
                </div>
                <div>
                  <dt>pulse count</dt>
                  <dd>{rootfield.pulseCount}</dd>
                </div>
                <div>
                  <dt>lanes</dt>
                  <dd>{rootfield.workLaneIds.join(", ")}</dd>
                </div>
                <div>
                  <dt>latest observation</dt>
                  <dd>
                    <HashValue value={rootfield.latestObservationId} />
                  </dd>
                </div>
                <div>
                  <dt>evidence URI</dt>
                  <dd>{rootfield.evidenceUri}</dd>
                </div>
              </dl>
              <ProvenanceLine provenance={rootfield.provenance} lastUpdated={rootfield.lastUpdated} />
            </article>
          ))}
        </section>
      ) : (
        <EmptyState
          title="No rootfields match"
          detail="Rootfield registry fixture entries will appear here after generated data is synced."
        />
      )}
    </div>
  );
}
