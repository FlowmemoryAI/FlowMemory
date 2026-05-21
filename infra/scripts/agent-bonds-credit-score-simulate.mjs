#!/usr/bin/env node
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { computeAgentCreditScoreFromReceipts } from "../../services/flowmemory/src/agent-credit-score.ts";
const score = computeAgentCreditScoreFromReceipts("agent_code_001");
const outPath = resolve("fixtures/agent-bonds/credit/credit-score-sim-report.json");
mkdirSync(dirname(outPath), { recursive: true });
writeFileSync(outPath, `${JSON.stringify({ schemaVersion: "agent-credit-score-sim-report/v1", generatedAt: new Date().toISOString(), score }, null, 2)}
`);
console.log(JSON.stringify({ service: "flowmemory-agent-bonds-credit-score-simulate", outPath, score: score.score, riskBand: score.riskBand }, null, 2));
