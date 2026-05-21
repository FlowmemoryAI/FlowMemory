#!/usr/bin/env node
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { sampleUnderwriterPool, allocatePoolCapacity, simulateLossWaterfall } from "../../services/flowmemory/src/underwriter-pools.ts";
const pool = sampleUnderwriterPool();
const allocation = allocatePoolCapacity({ pool, agentId: "agent_code_001", taskClass: "code.patch", allocatedCapacityUSDC: "50000000" });
const lossEvent = simulateLossWaterfall({ pool, allocation, taskId: "task_fixture_001", receiptId: "receipt_invalid_slash", reason: "agent_invalid_submission", amountSlashed: "10000000" });
const outPath = resolve("fixtures/agent-bonds/underwriters/loss-waterfall.sim-report.json");
mkdirSync(dirname(outPath), { recursive: true });
writeFileSync(outPath, `${JSON.stringify({ schemaVersion: "underwriter-loss-waterfall-sim-report/v1", generatedAt: new Date().toISOString(), pool, allocation, lossEvent, notes: ["Underwriter pools are capacity or recourse backing, not insurance."] }, null, 2)}
`);
console.log(JSON.stringify({ service: "flowmemory-agent-bonds-underwriter-simulate", outPath, lossEventId: lossEvent.lossEventId }, null, 2));
