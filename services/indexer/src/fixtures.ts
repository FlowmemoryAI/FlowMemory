import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import type { FlowPulseReceiptFixture, RawFlowPulseLogFixture } from "../../shared/src/index.ts";
import { buildTaskScoutReceiptFixtures } from "../../flowmemory/src/agent-memory.ts";

const __dirname = dirname(fileURLToPath(import.meta.url));

export function loadIndexerFixtureLogs(): RawFlowPulseLogFixture[] {
  const path = join(__dirname, "../fixtures/flowpulse-logs.json");
  const fixture = JSON.parse(readFileSync(path, "utf8")) as { logs: RawFlowPulseLogFixture[] };
  return fixture.logs;
}

export function loadIndexerFixtureReceipts(): FlowPulseReceiptFixture[] {
  const path = join(__dirname, "../fixtures/flowpulse-receipts.json");
  const fixture = JSON.parse(readFileSync(path, "utf8")) as { receipts: FlowPulseReceiptFixture[] };
  return [...fixture.receipts, ...buildTaskScoutReceiptFixtures() as FlowPulseReceiptFixture[]];
}
