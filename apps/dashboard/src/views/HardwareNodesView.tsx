import { useMemo, useState } from "react";
import { Search } from "lucide-react";
import { EmptyState } from "../components/EmptyState";
import { ProvenanceLine } from "../components/ProvenanceLine";
import { SectionHeader } from "../components/SectionHeader";
import { StatusBadge } from "../components/StatusBadge";
import { formatDateTime, formatPercent } from "../data/format";
import { searchRecords } from "../data/selectors";
import type { DashboardData } from "../data/types";

export function HardwareNodesView({ data }: { data: DashboardData }) {
  const [query, setQuery] = useState("");
  const nodes = useMemo(() => searchRecords(data.hardwareNodes, query), [data.hardwareNodes, query]);

  return (
    <div className="view-stack">
      <SectionHeader
        eyebrow="hardware"
        title="Hardware nodes"
        detail="Fixture heartbeats for FlowRouter, gateway, and Meshtastic/LoRa sidecar status."
        action={
          <label className="search-box">
            <Search size={16} aria-hidden="true" />
            <input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search nodes" />
          </label>
        }
      />

      {nodes.length > 0 ? (
        <section className="hardware-grid">
          {nodes.map((node) => (
            <article className="node-tile" key={node.nodeId}>
              <div className="tile-heading">
                <StatusBadge status={node.status} />
                <strong>{node.callsign}</strong>
              </div>
              <dl className="definition-grid">
                <div>
                  <dt>node id</dt>
                  <dd>{node.nodeId}</dd>
                </div>
                <div>
                  <dt>role</dt>
                  <dd>{node.role}</dd>
                </div>
                <div>
                  <dt>transport</dt>
                  <dd>{node.transport}</dd>
                </div>
                <div>
                  <dt>firmware</dt>
                  <dd>{node.firmware}</dd>
                </div>
                <div>
                  <dt>heartbeat</dt>
                  <dd>{formatDateTime(node.lastHeartbeatAt)}</dd>
                </div>
                <div>
                  <dt>battery</dt>
                  <dd>{formatPercent(node.batteryPercent)}</dd>
                </div>
                <div>
                  <dt>signal</dt>
                  <dd>{node.signalDbm === undefined ? "n/a" : `${node.signalDbm} dBm`}</dd>
                </div>
                <div>
                  <dt>temperature</dt>
                  <dd>{node.temperatureC === undefined ? "n/a" : `${node.temperatureC}C`}</dd>
                </div>
                <div>
                  <dt>lane</dt>
                  <dd>{node.linkedWorkLaneId ?? "none"}</dd>
                </div>
                <div>
                  <dt>location</dt>
                  <dd>{node.locationHint}</dd>
                </div>
              </dl>
              <ProvenanceLine provenance={node.provenance} lastUpdated={node.lastUpdated} />
            </article>
          ))}
        </section>
      ) : (
        <EmptyState
          title="No hardware nodes match"
          detail="Local node heartbeat fixtures should include subsystem, fixture origin, chain context, id, status, and last update."
        />
      )}
    </div>
  );
}

