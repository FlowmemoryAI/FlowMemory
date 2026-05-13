import { indexFlowPulseReceipts } from "./indexer.ts";
import { loadIndexerFixtureReceipts } from "./fixtures.ts";

const state = indexFlowPulseReceipts(loadIndexerFixtureReceipts(), {
  finalizedBlockNumber: "123458",
});

console.log(JSON.stringify({
  service: "flowmemory-indexer-v0",
  mode: "fixture",
  observationCount: state.observations.length,
  rootfieldCount: state.rootfields.length,
  duplicateCount: state.duplicates.length,
  rejectedLogCount: state.rejectedLogs.length,
  observations: state.observations,
}, null, 2));
