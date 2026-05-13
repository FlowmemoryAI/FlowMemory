import { existsSync } from "node:fs";
import { resolve } from "node:path";

import { indexFlowPulseReceipts, readIndexerState } from "../../indexer/src/index.ts";
import { loadIndexerFixtureReceipts } from "../../indexer/src/fixtures.ts";
import { loadVerifierArtifactFixture } from "./fixtures.ts";
import { verifyObservations } from "./verifier.ts";
import { writeVerifierReports } from "./persistence.ts";

const outArgIndex = process.argv.indexOf("--out");
const inputArgIndex = process.argv.indexOf("--input");
const outputPath = outArgIndex >= 0 ? process.argv[outArgIndex + 1] : "out/reports.json";
const inputPath = inputArgIndex >= 0 ? process.argv[inputArgIndex + 1] : "../indexer/out/indexer-state.json";

const indexerState = existsSync(inputPath)
  ? readIndexerState(inputPath).state
  : indexFlowPulseReceipts(loadIndexerFixtureReceipts(), { finalizedBlockNumber: "123458" });

const reports = verifyObservations(indexerState.observations, loadVerifierArtifactFixture());
writeVerifierReports(outputPath, reports);

console.log(JSON.stringify({
  service: "flowmemory-verifier-v0",
  inputPath: resolve(inputPath),
  outputPath: resolve(outputPath),
  reports: reports.length,
  statuses: reports.reduce<Record<string, number>>((counts, report) => {
    counts[report.reportCore.status] = (counts[report.reportCore.status] ?? 0) + 1;
    return counts;
  }, {}),
}, null, 2));
