import assert from "node:assert/strict";
import test from "node:test";
import { callControlPlaneMethod, loadControlPlaneState, type JsonObject } from "../src/index.ts";

const state = loadControlPlaneState();

test("exposes Agent Bonds phase 2 foundation and integration reads", () => {
  const gate = callControlPlaneMethod("agent_bond_phase2_gate_get", {}, { state }) as JsonObject;
  assert.equal((gate.gate as JsonObject).foundationReady, true);

  const passports = callControlPlaneMethod("agent_bond_passport_list", { limit: 10 }, { state }) as JsonObject;
  assert.ok(Array.isArray(passports.passports));
  assert.ok((passports.passports as JsonObject[]).length > 0);

  const envelopeQuote = callControlPlaneMethod("agent_bond_envelope_quote", { taskClass: "code.patch", payoutUSDC: "50000000" }, { state }) as JsonObject;
  assert.equal(((envelopeQuote.quote as JsonObject).task as JsonObject).taskClass, "code.patch");

  const receipts = callControlPlaneMethod("agent_bond_receipt_list", { agentId: "agent_code_001", limit: 10 }, { state }) as JsonObject;
  assert.ok(Array.isArray(receipts.receipts));
  assert.ok((receipts.receipts as JsonObject[]).length > 0);
});

test("exposes Agent Bonds A2A MCP x402 credit and claim reads", () => {
  const card = callControlPlaneMethod("agent_bond_a2a_agent_card_get", { agentId: "agent_code_001" }, { state }) as JsonObject;
  assert.ok(Array.isArray((card.agentCard as JsonObject).extensions));

  const mcp = callControlPlaneMethod("agent_bond_mcp_tools_get", {}, { state }) as JsonObject;
  assert.ok(Array.isArray((mcp.tools as JsonObject).tools));

  const x402 = callControlPlaneMethod("agent_bond_x402_payment_intent_create", { mode: "service_payment" }, { state }) as JsonObject;
  assert.equal((x402.intent as JsonObject).mode, "service_payment");

  const credit = callControlPlaneMethod("agent_bond_credit_score_get", { agentId: "agent_code_001" }, { state }) as JsonObject;
  assert.ok(typeof (credit.score as JsonObject).score === "number");

  const pools = callControlPlaneMethod("agent_bond_underwriter_pool_list", {}, { state }) as JsonObject;
  assert.ok(Array.isArray(pools.pools));

  const recoursePolicy = callControlPlaneMethod("agent_bond_recourse_policy_get", {}, { state }) as JsonObject;
  assert.equal((recoursePolicy.policy as JsonObject).policyId, "recourse-api-data-low-risk-v1");

  const recourseDecision = callControlPlaneMethod("agent_bond_recourse_decision_quote", { agentId: "agent_data_001" }, { state }) as JsonObject;
  assert.equal((recourseDecision.decision as JsonObject).status, "approved");
  assert.equal(typeof (((recourseDecision.decision as JsonObject).policyAttestation as JsonObject).attestationId), "string");

  const waterfall = callControlPlaneMethod("agent_bond_failure_waterfall_get", {}, { state }) as JsonObject;
  assert.equal((waterfall.waterfall as JsonObject).terminalState, "slashed_invalid");

  const claim = callControlPlaneMethod("agent_bond_public_claim_status_get", {}, { state }) as JsonObject;
  assert.equal((claim.status as JsonObject).broadPublicLaunchBlocked, true);
});
