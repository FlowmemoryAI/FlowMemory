import { useMemo, useState } from "react";
import { Braces } from "lucide-react";
import { SectionHeader } from "../components/SectionHeader";
import type { DashboardData } from "../data/types";

const DATASET_LABELS = [
  "all",
  "metadata",
  "chain",
  "flowPulseObservations",
  "rootfields",
  "workLanes",
  "workReceipts",
  "verifierReports",
  "devnetBlocks",
  "hardwareNodes",
  "alerts",
] as const;

type DatasetKey = (typeof DATASET_LABELS)[number];

export function RawJsonInspectorView({ data }: { data: DashboardData }) {
  const [dataset, setDataset] = useState<DatasetKey>("all");

  const rawJson = useMemo(() => {
    const value = dataset === "all" ? data : data[dataset];
    return JSON.stringify(value, null, 2);
  }, [data, dataset]);

  return (
    <div className="view-stack">
      <SectionHeader
        eyebrow="fixture inspector"
        title="Raw JSON"
        detail="Direct view of the loaded runtime fixture for debugging app-facing data shape."
        action={
          <select value={dataset} onChange={(event) => setDataset(event.target.value as DatasetKey)}>
            {DATASET_LABELS.map((label) => (
              <option key={label} value={label}>
                {label}
              </option>
            ))}
          </select>
        }
      />

      <section className="json-panel">
        <div className="json-panel-header">
          <Braces size={16} aria-hidden="true" />
          <span>{data.metadata.runtimeDataPath}</span>
          <strong>{dataset}</strong>
        </div>
        <pre>{rawJson}</pre>
      </section>
    </div>
  );
}
