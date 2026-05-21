import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import test from "node:test";

import { validateAgentBondPassport, computePassportCapacityView } from "../src/agent-bond-passport.ts";
import { validateBondedTaskEnvelope, computeEnvelopeHash, envelopeFromA2AMessage } from "../src/bonded-task-envelope.ts";
import { validateBondedExecutionReceipt, computeReceiptHash, receiptToPassportReputationDelta, listReceiptsForAgent } from "../src/bonded-execution-receipt.ts";
import { getAgentBondsFoundationReadiness, getAgentBondsPhase2Gate } from "../src/agent-bonds-phase2-gate.ts";
import { buildA2AAgentBondsExtension, buildA2AAgentCardFromPassport } from "../src/a2a-agent-bonds.ts";
import { createX402EscrowBridgeIntent, linkX402PaymentToEnvelope } from "../src/x402-agent-bonds.ts";
import { computeAgentCreditScoreFromReceipts, buildCreditScoreAttestation, validateCreditScoreAttestation } from "../src/agent-credit-score.ts";
import { sampleUnderwriterPool, allocatePoolCapacity, simulateLossWaterfall, applyUnderwriterCapacityToPassport } from "../src/underwriter-pools.ts";
import { buildPublicClaimPackage, scanUnsafeAgentBondClaims, validatePublicClaimPackage } from "../src/agent-bonds-public-claim.ts";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../../..");
process.chdir(REPO_ROOT);

function readJson(path: string) {
  return JSON.parse(readFileSync(resolve(REPO_ROOT, path), "utf8"));
}
function runNodeScript(args: string[]) {
  const result = spawnSync("node", args, { cwd: REPO_ROOT, encoding: "utf8" });
  return { status: result.status, stdout: result.stdout, stderr: result.stderr };
}

test("phase2 schemas validate fixture passports envelopes and receipts", () => {
  const passport = validateAgentBondPassport(readJson("fixtures/agent-bonds/passports/agent-passport.code-agent.template.json"));
  const envelope = validateBondedTaskEnvelope(readJson("fixtures/agent-bonds/envelopes/bonded-task-envelope.code-patch.template.json"));
  const receipt = validateBondedExecutionReceipt(readJson("fixtures/agent-bonds/receipts/bonded-execution-receipt.success.template.json"));
  assert.equal(passport.schemaVersion, "agent-bond-passport/v1");
  assert.equal(envelope.schemaVersion, "bonded-task-envelope/v1");
  assert.equal(receipt.schemaVersion, "bonded-execution-receipt/v1");
});

test("phase2 foundation and gate are ready while broad claim remains blocked", () => {
  const foundation = getAgentBondsFoundationReadiness();
  const gate = getAgentBondsPhase2Gate();
  assert.equal(foundation.readyForPhase2, true);
  assert.equal(gate.foundationReady, true);
  assert.equal(gate.publicLaunchClaimAllowed, true);
  const blockedClaim = buildPublicClaimPackage({ claimLevel: "broad_public_launch" });
  assert.equal(blockedClaim.enabled, false);
  const integrationClaim = validatePublicClaimPackage(buildPublicClaimPackage({ claimLevel: "integration_beta" }));
  assert.equal(integrationClaim.claimLevel, "integration_beta");
});

test("phase2 runtime helpers are deterministic and linked", () => {
  const passport = validateAgentBondPassport(readJson("fixtures/agent-bonds/passports/agent-passport.code-agent.template.json"));
  const envelope = validateBondedTaskEnvelope(readJson("fixtures/agent-bonds/envelopes/bonded-task-envelope.code-patch.template.json"));
  const receipt = validateBondedExecutionReceipt(readJson("fixtures/agent-bonds/receipts/bonded-execution-receipt.success.template.json"));
  assert.equal(computeEnvelopeHash(envelope), envelope.envelopeHash);
  assert.equal(computeReceiptHash(receipt), receipt.receiptHash);
  assert.equal((computePassportCapacityView(String(passport.agentId)).canAcceptNewTask), true);
  assert.equal((receiptToPassportReputationDelta(receipt).agent as Record<string, unknown>).completedDelta, 1);
  assert.ok(listReceiptsForAgent("agent_code_001").length > 0);
  const a2aMessage = readJson("fixtures/agent-bonds/a2a/a2a-message.bonded-task.json");
  assert.equal(envelopeFromA2AMessage(a2aMessage).envelopeId, envelope.envelopeId);
  assert.equal((buildA2AAgentBondsExtension(passport).uri), "https://flowmemory.ai/a2a/extensions/agent-bonds/v1");
  assert.ok(Array.isArray(buildA2AAgentCardFromPassport(passport).extensions));
});

test("phase2 x402 credit and underwriter helpers work", () => {
  const envelope = validateBondedTaskEnvelope(readJson("fixtures/agent-bonds/envelopes/bonded-task-envelope.x402-funded.template.json"));
  const intent = createX402EscrowBridgeIntent(envelope);
  assert.equal(intent.envelopeHash, envelope.envelopeHash);
  assert.equal(linkX402PaymentToEnvelope(intent, envelope).envelopeHash, envelope.envelopeHash);
  const score = computeAgentCreditScoreFromReceipts("agent_code_001");
  const attestation = buildCreditScoreAttestation(score, "fixture-signer");
  assert.equal(validateCreditScoreAttestation(attestation).riskBand, score.riskBand);
  const pool = sampleUnderwriterPool();
  const allocation = allocatePoolCapacity({ pool, agentId: "agent_code_001", taskClass: "code.patch", allocatedCapacityUSDC: "50000000" });
  assert.equal(allocation.agentId, "agent_code_001");
  const loss = simulateLossWaterfall({ pool, allocation, taskId: "task_fixture_001", receiptId: "receipt_invalid_slash", reason: "agent_invalid_submission", amountSlashed: "10000000" });
  assert.equal(loss.reason, "agent_invalid_submission");
  const passport = validateAgentBondPassport(readJson("fixtures/agent-bonds/passports/agent-passport.code-agent.template.json"));
  assert.notEqual((applyUnderwriterCapacityToPassport(passport, [allocation]).capacity as Record<string, unknown>).maxOpenExposureUSDC, passport.capacity?.maxOpenExposureUSDC);
});

test("phase2 unsafe claim scan catches forbidden phrases", () => {
  const scan = scanUnsafeAgentBondClaims("This is risk-free and fully insured.");
  assert.equal(scan.ok, false);
  assert.ok((scan.matches as string[]).length >= 2);
});

test("phase2 scripts produce reports", () => {
  for (const args of [
    ["infra/scripts/agent-bonds-phase2-gate.mjs"],
    ["infra/scripts/agent-bonds-a2a-validate.mjs"],
    ["infra/scripts/agent-bonds-mcp-smoke.mjs"],
    ["infra/scripts/agent-bonds-x402-smoke.mjs"],
    ["infra/scripts/agent-bonds-credit-score-simulate.mjs"],
    ["infra/scripts/agent-bonds-underwriter-simulate.mjs"],
    ["infra/scripts/agent-bonds-public-claim-validate.mjs"],
  ]) {
    const result = runNodeScript(args);
    assert.equal(result.status, 0, result.stderr || result.stdout);
  }
});
