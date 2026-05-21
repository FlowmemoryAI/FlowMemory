#!/usr/bin/env node
import { readJson } from "../../services/flowmemory/src/agent-bonds-phase2-shared.ts";
import { buildRecourseDecision, buildFailureWaterfall, sampleRecoursePolicy, getApiDataPilotTemplate } from "../../services/flowmemory/src/agent-bonds-recourse-policy.ts";
import { computeAgentCreditScoreFromReceipts } from "../../services/flowmemory/src/agent-credit-score.ts";

const { passport, envelope, policy } = getApiDataPilotTemplate();
const pool = readJson("fixtures/agent-bonds/underwriters/pool.usdc-recourse.template.json");
const score = computeAgentCreditScoreFromReceipts(String(passport.agentId));
const decision = buildRecourseDecision({ policy, envelope, passport, pool, score });
const receipt = readJson("fixtures/agent-bonds/receipts/bonded-execution-receipt.invalid-slash.template.json");
const waterfall = buildFailureWaterfall({ receipt, recourseDecision: decision });
console.log(JSON.stringify({ service: "flowmemory-agent-bonds-recourse-simulate", decision, waterfall }, null, 2));
