import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";

import { computeAgentCreditScoreFromReceipts } from "../src/agent-credit-score.ts";
import {
  buildFailureWaterfall,
  buildRecourseDecision,
  getApiDataPilotTemplate,
  recourseFoundationPresent,
  sampleRecoursePolicy,
  validateAgentBondsRecoursePolicyAttestation,
  validateAgentBondsFailureWaterfall,
  validateAgentBondsRecourseDecision,
  validateAgentBondsRecoursePolicy,
  verifyRecourseDecisionPolicyAttestation,
} from "../src/agent-bonds-recourse-policy.ts";
import { validateBondedExecutionReceipt } from "../src/bonded-execution-receipt.ts";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../../..");
process.chdir(REPO_ROOT);

function readJson(path: string) {
  return JSON.parse(readFileSync(resolve(REPO_ROOT, path), "utf8"));
}

test("recourse policy schemas validate fixtures", () => {
  const policy = validateAgentBondsRecoursePolicy(readJson("fixtures/agent-bonds/recourse/recourse-policy.api-data.low-risk.json"));
  const decision = validateAgentBondsRecourseDecision(readJson("fixtures/agent-bonds/recourse/recourse-decision.api-data.approved.json"));
  const waterfall = validateAgentBondsFailureWaterfall(readJson("fixtures/agent-bonds/recourse/failure-waterfall.invalid-submission.json"));
  const attestation = validateAgentBondsRecoursePolicyAttestation(readJson("fixtures/agent-bonds/recourse/policy-attestation.api-data.approved.json"));
  assert.equal(policy.schemaVersion, "agent-bonds-recourse-policy/v1");
  assert.equal(decision.schemaVersion, "agent-bonds-recourse-decision/v1");
  assert.equal(waterfall.schemaVersion, "agent-bonds-failure-waterfall/v1");
  assert.equal(attestation.schemaVersion, "agent-bonds-recourse-policy-attestation/v1");
  assert.equal(recourseFoundationPresent(), true);
  assert.equal(verifyRecourseDecisionPolicyAttestation({
    decision,
    trustedSignerIds: [String(attestation.signerId)],
    now: "2026-05-21T12:00:00.000Z",
  }), true);
});

test("recourse policy attestation fails closed on quote mutation", () => {
  const decision = validateAgentBondsRecourseDecision(readJson("fixtures/agent-bonds/recourse/recourse-decision.api-data.approved.json"));
  const mutated = structuredClone(decision);
  mutated.approvedCoverageUSDC = "1";
  assert.equal(verifyRecourseDecisionPolicyAttestation({
    decision: mutated,
    trustedSignerIds: ["0x1111111111111111111111111111111111111111111111111111111111111111"],
    now: "2026-05-21T12:00:00.000Z",
  }), false);
});

test("api data pilot receives approved recourse decision", () => {
  const { passport, envelope, policy } = getApiDataPilotTemplate();
  const pool = readJson("fixtures/agent-bonds/underwriters/pool.usdc-recourse.template.json");
  const decision = buildRecourseDecision({
    policy,
    envelope,
    passport,
    pool,
    currentAgentCoverageUSDC: "0",
    currentRequesterCoverageUSDC: "0",
    currentVerifierCoverageUSDC: "0",
  });
  assert.equal(decision.status, "approved");
  assert.equal(BigInt(String(decision.approvedCoverageUSDC)) > 0n, true);
  assert.ok((decision.reasonCodes as string[]).includes("TASK_CLASS_ALLOWED"));
});

test("recourse decision denies excluded or mispriced tasks", () => {
  const { passport, envelope, policy } = getApiDataPilotTemplate();
  const pool = readJson("fixtures/agent-bonds/underwriters/pool.usdc-recourse.template.json");
  const badEnvelope = structuredClone(envelope);
  (badEnvelope.task as Record<string, unknown>).taskClass = "research.open_ended";
  const denied = buildRecourseDecision({ policy, envelope: badEnvelope, passport, pool });
  assert.notEqual(denied.status, "approved");
  assert.ok((denied.reasonCodes as string[]).includes("TASK_CLASS_NOT_ALLOWED") || (denied.reasonCodes as string[]).includes("TASK_CLASS_EXCLUDED"));

  const lowFee = structuredClone(envelope);
  (lowFee.economics as Record<string, unknown>).verifierFeeUSDC = "1";
  (lowFee.economics as Record<string, unknown>).requesterCancelBondUSDC = "1";
  const feeDenied = buildRecourseDecision({ policy, envelope: lowFee, passport, pool });
  assert.notEqual(feeDenied.status, "approved");
  assert.ok((feeDenied.reasonCodes as string[]).includes("FEE_RATIO_TOO_LOW"));
});

test("failure waterfall is deterministic for covered invalid receipt", () => {
  const receipt = validateBondedExecutionReceipt(readJson("fixtures/agent-bonds/receipts/bonded-execution-receipt.invalid-slash.template.json"));
  const decision = validateAgentBondsRecourseDecision(readJson("fixtures/agent-bonds/recourse/recourse-decision.api-data.approved.json"));
  const waterfallA = buildFailureWaterfall({ receipt, recourseDecision: decision });
  const waterfallB = buildFailureWaterfall({ receipt, recourseDecision: decision });
  assert.deepEqual(waterfallA.components, waterfallB.components);
  assert.equal((waterfallA.totals as Record<string, unknown>).recourseUSDC, decision.approvedCoverageUSDC);
  assert.ok(Array.isArray(waterfallA.components));
});
