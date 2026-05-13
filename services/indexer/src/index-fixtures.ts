import { resolve } from "node:path";

import { indexFlowPulseReceipts } from "./indexer.ts";
import { loadIndexerFixtureReceipts } from "./fixtures.ts";
import { writeIndexerState } from "./persistence.ts";

const outArgIndex = process.argv.indexOf("--out");
const outputPath = outArgIndex >= 0 ? process.argv[outArgIndex + 1] : "out/indexer-state.json";

const state = indexFlowPulseReceipts(loadIndexerFixtureReceipts(), {
  finalizedBlockNumber: "123458",
});

writeIndexerState(outputPath, state);

console.log(JSON.stringify({
  service: "flowmemory-indexer-v0",
  outputPath: resolve(outputPath),
  observations: state.observations.length,
  cursors: state.cursors.length,
  rejectedLogs: state.rejectedLogs.length,
  duplicates: state.duplicates.length,
}, null, 2));
