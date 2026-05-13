import { Database, HardDrive, Radio, ServerCog } from "lucide-react";
import type { Provenance } from "../data/types";

const ORIGIN_LABELS: Record<Provenance["origin"], string> = {
  fixture: "fixture",
  local: "local",
  live: "live",
};

function OriginIcon({ origin }: { origin: Provenance["origin"] }) {
  if (origin === "fixture") {
    return <Database size={13} aria-hidden="true" />;
  }
  if (origin === "local") {
    return <HardDrive size={13} aria-hidden="true" />;
  }
  return <Radio size={13} aria-hidden="true" />;
}

export function ProvenanceLine({ provenance, lastUpdated }: { provenance: Provenance; lastUpdated?: string }) {
  return (
    <div className="provenance-line">
      <span className="provenance-chip" title={`source subsystem: ${provenance.subsystem}`}>
        <ServerCog size={13} aria-hidden="true" />
        {provenance.subsystem}
      </span>
      <span className="provenance-chip" title={`data origin: ${ORIGIN_LABELS[provenance.origin]}`}>
        <OriginIcon origin={provenance.origin} />
        {ORIGIN_LABELS[provenance.origin]}
      </span>
      <span className="provenance-chip" title={`chain context: ${provenance.chainContext}`}>
        {provenance.chainContext}
      </span>
      {lastUpdated ? (
        <span className="provenance-chip" title={`last updated: ${lastUpdated}`}>
          {new Date(lastUpdated).toLocaleString()}
        </span>
      ) : null}
    </div>
  );
}

