import { existsSync, readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { indexFlowPulseReceipts } from "./indexer.ts";
import { loadIndexerFixtureReceipts } from "./fixtures.ts";
import { writeIndexerState } from "./persistence.ts";

const outArgIndex = process.argv.indexOf("--out");
const outputPath = outArgIndex >= 0 ? process.argv[outArgIndex + 1] : "out/indexer-state.json";
const sourceDir = dirname(fileURLToPath(import.meta.url));
const explorerFallbackPath = resolve(sourceDir, "..", "..", "..", "fixtures", "dashboard", "flowmemory-network-explorer-fallback.json");
const explorerFallback = existsSync(explorerFallbackPath)
  ? JSON.parse(readFileSync(explorerFallbackPath, "utf8")) as unknown
  : undefined;

const state = indexFlowPulseReceipts(loadIndexerFixtureReceipts(), {
  finalizedBlockNumber: "123458",
  explorerFallback,
});

writeIndexerState(outputPath, state);

console.log(JSON.stringify({
  service: "flowmemory-indexer-v0",
  outputPath: resolve(outputPath),
  observations: state.observations.length,
  cursors: state.cursors.length,
  rejectedLogs: state.rejectedLogs.length,
  duplicates: state.duplicates.length,
  explorer: state.explorer.counts,
}, null, 2));
