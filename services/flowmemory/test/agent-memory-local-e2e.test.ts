import assert from "node:assert/strict";
import test from "node:test";

import { runAgentMemoryLocalE2E } from "../src/agent-memory-local-e2e.ts";

test("runs actual deployed-log Base agent memory e2e", async () => {
  const report = await runAgentMemoryLocalE2E();

  assert.equal(report.schema, "flowmemory.base_agent_memory.local_e2e.v1");
  assert.equal(report.chainId, "31337");
  assert.equal(typeof report.deployed.baseOnchainAgentMemory, "string");
  assert.equal(typeof report.deployed.taskTarget, "string");
  assert.equal(report.indexer.observations, 2);
  assert.equal(report.indexer.rejectedLogs, 0);
  assert.equal(report.verifier.reports, 2);
  assert.equal(report.verifier.statusCounts.valid, 2);
});
