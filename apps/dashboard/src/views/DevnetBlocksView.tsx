import { useMemo, useState } from "react";
import { Search } from "lucide-react";
import { EmptyState } from "../components/EmptyState";
import { HashValue } from "../components/HashValue";
import { ProvenanceLine } from "../components/ProvenanceLine";
import { SectionHeader } from "../components/SectionHeader";
import { StatusBadge } from "../components/StatusBadge";
import { formatDateTime } from "../data/format";
import { searchRecords } from "../data/selectors";
import type { DashboardData } from "../data/types";

export function DevnetBlocksView({ data }: { data: DashboardData }) {
  const [query, setQuery] = useState("");
  const blocks = useMemo(() => searchRecords(data.devnetBlocks, query), [data.devnetBlocks, query]);

  return (
    <div className="view-stack">
      <SectionHeader
        eyebrow="devnet"
        title="Blocks and state roots"
        detail="Local Anvil/devnet fixture blocks with state roots, receipt roots, and finality distance."
        action={
          <label className="search-box">
            <Search size={16} aria-hidden="true" />
            <input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search blocks" />
          </label>
        }
      />

      <section className="table-panel">
        {blocks.length > 0 ? (
          <div className="table-scroll">
            <table>
              <thead>
                <tr>
                  <th>Status</th>
                  <th>Block</th>
                  <th>Hashes</th>
                  <th>Roots</th>
                  <th>Counts</th>
                  <th>Provenance</th>
                </tr>
              </thead>
              <tbody>
                {blocks.map((block) => (
                  <tr key={block.blockHash}>
                    <td>
                      <StatusBadge status={block.status} />
                    </td>
                    <td>
                      <div className="cell-stack">
                        <strong>{block.blockNumber}</strong>
                        <small>{formatDateTime(block.timestamp)}</small>
                      </div>
                    </td>
                    <td>
                      <div className="cell-stack">
                        <span>
                          block <HashValue value={block.blockHash} trim="short" />
                        </span>
                        <span>
                          parent <HashValue value={block.parentHash} trim="short" />
                        </span>
                      </div>
                    </td>
                    <td>
                      <div className="cell-stack">
                        <span>
                          state <HashValue value={block.stateRoot} trim="short" />
                        </span>
                        <span>
                          receipts <HashValue value={block.receiptsRoot} trim="short" />
                        </span>
                      </div>
                    </td>
                    <td>
                      <div className="cell-stack">
                        <span>{block.observationCount} observations</span>
                        <small>{block.reportCount} reports / distance {block.finalityDistance}</small>
                      </div>
                    </td>
                    <td>
                      <ProvenanceLine provenance={block.provenance} lastUpdated={block.lastUpdated} />
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <EmptyState
            title="No devnet blocks match"
            detail="Generated devnet snapshots should provide block hash, state root, receipts root, status, and update time."
          />
        )}
      </section>
    </div>
  );
}
