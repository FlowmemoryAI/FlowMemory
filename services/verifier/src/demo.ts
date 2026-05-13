import { indexFlowPulseReceipts } from "../../indexer/src/index.ts";
import { loadIndexerFixtureReceipts } from "../../indexer/src/fixtures.ts";
import { loadVerifierArtifactFixture } from "./fixtures.ts";
import { verifyObservations } from "./verifier.ts";

const indexerState = indexFlowPulseReceipts(loadIndexerFixtureReceipts(), {
  finalizedBlockNumber: "123458",
});
const reports = verifyObservations(indexerState.observations, loadVerifierArtifactFixture());

console.log(JSON.stringify({
  service: "flowmemory-verifier-v0",
  mode: "fixture",
  reportCount: reports.length,
  statuses: reports.map((report) => report.reportCore.status),
  reports,
}, null, 2));
