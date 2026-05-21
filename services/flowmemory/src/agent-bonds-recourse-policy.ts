import * as secp from "@noble/secp256k1";
import { hmac } from "@noble/hashes/hmac.js";
import { sha256 } from "@noble/hashes/sha2.js";
import { addDecimalStrings, decimal, fileExists, readJson, stableHash, validateWithSchema, type JsonObject, type JsonValue } from "./agent-bonds-phase2-shared.ts";
import type { AgentBondPassport } from "./agent-bond-passport.ts";
import type { BondedTaskEnvelope } from "./bonded-task-envelope.ts";
import type { AgentCreditScore } from "./agent-credit-score.ts";
import type { UnderwriterPool } from "./underwriter-pools.ts";
import type { BondedExecutionReceipt } from "./bonded-execution-receipt.ts";


secp.hashes.sha256 = sha256;
secp.hashes.hmacSha256 = (key: Uint8Array, ...messages: Uint8Array[]) => hmac(sha256, key, secp.etc.concatBytes(...messages));
export type AgentBondsRecoursePolicy = JsonObject;
export type AgentBondsRecourseDecision = JsonObject;
export type AgentBondsFailureWaterfall = JsonObject;
export type AgentBondsRecoursePolicyAttestation = JsonObject;

const POLICY_SCHEMA = "schemas/flowmemory/agent-bonds-recourse-policy.schema.json";
const DECISION_SCHEMA = "schemas/flowmemory/agent-bonds-recourse-decision.schema.json";
const WATERFALL_SCHEMA = "schemas/flowmemory/agent-bonds-failure-waterfall.schema.json";
const POLICY_ATTESTATION_SCHEMA = "schemas/flowmemory/agent-bonds-recourse-policy-attestation.schema.json";

export function validateAgentBondsRecoursePolicy(input: unknown): AgentBondsRecoursePolicy {
  return validateWithSchema<AgentBondsRecoursePolicy>(POLICY_SCHEMA, input);
}

export function validateAgentBondsRecourseDecision(input: unknown): AgentBondsRecourseDecision {
  return validateWithSchema<AgentBondsRecourseDecision>(DECISION_SCHEMA, input);
}

export function validateAgentBondsFailureWaterfall(input: unknown): AgentBondsFailureWaterfall {
  return validateWithSchema<AgentBondsFailureWaterfall>(WATERFALL_SCHEMA, input);
}

export function validateAgentBondsRecoursePolicyAttestation(input: unknown): AgentBondsRecoursePolicyAttestation {
  return validateWithSchema<AgentBondsRecoursePolicyAttestation>(POLICY_ATTESTATION_SCHEMA, input);
}

function hexToBytes(value: string, bytes: number): Uint8Array {
  const prefixed = value.startsWith("0x") ? value.slice(2) : value;
  if (!/^[0-9a-fA-F]+$/.test(prefixed) || prefixed.length !== bytes * 2) {
    throw new Error(`expected ${bytes} byte hex value`);
  }
  const output = new Uint8Array(bytes);
  for (let index = 0; index < bytes; index += 1) output[index] = Number.parseInt(prefixed.slice(index * 2, index * 2 + 2), 16);
  return output;
}

export function recourseDecisionAttestedFields(decision: AgentBondsRecourseDecision): JsonObject {
  const { policyAttestation: _policyAttestation, ...fields } = decision as JsonObject;
  return fields;
}

export function recourseDecisionHash(decision: AgentBondsRecourseDecision): `0x${string}` {
  return stableHash("agent-bonds-recourse-decision/attested-fields/v1", recourseDecisionAttestedFields(decision) as JsonValue);
}

export function recoursePolicyAttestationDigest(input: {
  decision: AgentBondsRecourseDecision;
  signerId: string;
  signerKeyId: string;
  issuedAt: string;
  expiresAt: string;
  nonce: string;
}): `0x${string}` {
  return stableHash("agent-bonds-recourse-policy-attestation/signing-digest/v1", {
    decisionHash: recourseDecisionHash(input.decision),
    decisionId: input.decision.decisionId,
    policyId: input.decision.policyId,
    envelopeId: input.decision.envelopeId,
    signerId: input.signerId,
    signerKeyId: input.signerKeyId,
    issuedAt: input.issuedAt,
    expiresAt: input.expiresAt,
    nonce: input.nonce,
  });
}

export function buildRecoursePolicyAttestation(input: {
  decision: AgentBondsRecourseDecision;
  signerId: string;
  signerKeyId: string;
  publicKey: string;
  signature: string;
  issuedAt: string;
  expiresAt: string;
  nonce: string;
}): AgentBondsRecoursePolicyAttestation {
  const decisionHash = recourseDecisionHash(input.decision);
  const signingDigest = recoursePolicyAttestationDigest(input);
  return validateAgentBondsRecoursePolicyAttestation({
    schemaVersion: "agent-bonds-recourse-policy-attestation/v1",
    attestationId: stableHash("agent-bonds-recourse-policy-attestation/id/v1", {
      decisionHash,
      signingDigest,
      signerId: input.signerId,
      signerKeyId: input.signerKeyId,
    }),
    decisionId: input.decision.decisionId,
    policyId: input.decision.policyId,
    envelopeId: input.decision.envelopeId,
    decisionHash,
    signerId: input.signerId,
    signerKeyId: input.signerKeyId,
    publicKey: input.publicKey,
    signatureAlgorithm: "secp256k1-keccak256-flowmemory-recourse-policy-v1",
    signingDigest,
    signature: input.signature,
    issuedAt: input.issuedAt,
    expiresAt: input.expiresAt,
    nonce: input.nonce,
  });
}

export function attachRecoursePolicyAttestation(
  decision: AgentBondsRecourseDecision,
  policyAttestation: AgentBondsRecoursePolicyAttestation,
): AgentBondsRecourseDecision {
  return validateAgentBondsRecourseDecision({ ...decision, policyAttestation });
}

export function verifyRecourseDecisionPolicyAttestation(input: {
  decision: AgentBondsRecourseDecision;
  trustedSignerIds?: string[];
  now?: string;
}): boolean {
  const attestation = validateAgentBondsRecoursePolicyAttestation((input.decision as JsonObject).policyAttestation);
  if (attestation.decisionId !== input.decision.decisionId || attestation.policyId !== input.decision.policyId || attestation.envelopeId !== input.decision.envelopeId) return false;
  if (attestation.decisionHash !== recourseDecisionHash(input.decision)) return false;
  if (Array.isArray(input.trustedSignerIds) && !input.trustedSignerIds.includes(String(attestation.signerId))) return false;
  if (input.now !== undefined && Date.parse(input.now) > Date.parse(String(attestation.expiresAt))) return false;
  const expectedDigest = recoursePolicyAttestationDigest({
    decision: input.decision,
    signerId: String(attestation.signerId),
    signerKeyId: String(attestation.signerKeyId),
    issuedAt: String(attestation.issuedAt),
    expiresAt: String(attestation.expiresAt),
    nonce: String(attestation.nonce),
  });
  if (attestation.signingDigest !== expectedDigest) return false;
  return secp.verify(
    hexToBytes(String(attestation.signature), 64),
    hexToBytes(expectedDigest, 32),
    hexToBytes(String(attestation.publicKey), 33),
    { prehash: false },
  );
}

export function sampleRecoursePolicy(): AgentBondsRecoursePolicy {
  return validateAgentBondsRecoursePolicy(readJson("fixtures/agent-bonds/recourse/recourse-policy.api-data.low-risk.json"));
}

export function buildRecourseDecision(input: {
  policy: AgentBondsRecoursePolicy;
  envelope: BondedTaskEnvelope;
  passport: AgentBondPassport;
  pool: UnderwriterPool;
  score?: AgentCreditScore;
  currentAgentCoverageUSDC?: string;
  currentRequesterCoverageUSDC?: string;
  currentVerifierCoverageUSDC?: string;
}): AgentBondsRecourseDecision {

function uintFromUnknown(value: unknown, fallback = 0n): bigint {
  if (typeof value === "string" && /^\d+$/.test(value)) return BigInt(value);
  if (typeof value === "number" && Number.isInteger(value) && value >= 0) return BigInt(value);
  return fallback;
}

  const policy = input.policy;
  const envelope = input.envelope;
  const passport = input.passport;
  const pool = input.pool;
  const scope = (policy.scope ?? {}) as JsonObject;
  const constraints = (policy.constraints ?? {}) as JsonObject;
  const pricing = (policy.pricing ?? {}) as JsonObject;
  const taskClass = String(((envelope.task as JsonObject).taskClass) ?? "unknown");
  const riskTier = Number(((envelope.policy as JsonObject).riskTier) ?? 0);
  const payoutUSDC = BigInt(decimal(((envelope.economics as JsonObject).payoutUSDC)));
  const coverageRatioBps = uintFromUnknown(pricing.coverageRatioBps);
  const requestedCoverageUSDC = coverageRatioBps * payoutUSDC / 10_000n;
  const availablePoolUSDC = BigInt(decimal(((pool.capacity as JsonObject).totalAvailable)));
  const maxCoveragePerTaskUSDC = BigInt(decimal(constraints.maxCoveragePerTaskUSDC));
  const maxCoveragePerAgentUSDC = BigInt(decimal(constraints.maxCoveragePerAgentUSDC));
  const maxCoveragePerRequesterUSDC = BigInt(decimal(constraints.maxCoveragePerRequesterUSDC));
  const maxCoveragePerVerifierUSDC = BigInt(decimal(constraints.maxCoveragePerVerifierUSDC));
  const maxCoveragePerPoolUSDC = BigInt(decimal(constraints.maxCoveragePerPoolUSDC));
  const stakeCapacityUSDC = BigInt(decimal(((passport.stake as JsonObject).stakeCapacityUSDC)));
  const agentOpenCoverageUSDC = BigInt(input.currentAgentCoverageUSDC ?? "0");
  const requesterOpenCoverageUSDC = BigInt(input.currentRequesterCoverageUSDC ?? "0");
  const verifierOpenCoverageUSDC = BigInt(input.currentVerifierCoverageUSDC ?? "0");
  const reasonCodes: string[] = [];

  const supportedTaskClasses = Array.isArray(scope.taskClasses) ? scope.taskClasses.map(String) : [];
  if (supportedTaskClasses.length > 0 && !supportedTaskClasses.includes(taskClass)) reasonCodes.push("TASK_CLASS_NOT_ALLOWED");
  if (Array.isArray(constraints.excludedTaskClasses) && constraints.excludedTaskClasses.map(String).includes(taskClass)) reasonCodes.push("TASK_CLASS_EXCLUDED");
  if (riskTier > Number(scope.maxRiskTier ?? riskTier)) reasonCodes.push("RISK_TIER_TOO_HIGH");
  if (String(((envelope.economics as JsonObject).settlementToken ?? "")).toLowerCase() !== String((scope.settlementToken ?? "")).toLowerCase()) reasonCodes.push("SETTLEMENT_TOKEN_MISMATCH");
  if ((constraints.requireObjectiveAcceptanceCriteria) === true && ((envelope.task as JsonObject).objectiveOnly) !== true) reasonCodes.push("OBJECTIVE_TASK_REQUIRED");
  if (requestedCoverageUSDC > maxCoveragePerTaskUSDC) reasonCodes.push("TASK_COVERAGE_CAP_EXCEEDED");
  if (agentOpenCoverageUSDC + requestedCoverageUSDC > maxCoveragePerAgentUSDC) reasonCodes.push("AGENT_COVERAGE_CAP_EXCEEDED");
  if (requesterOpenCoverageUSDC + requestedCoverageUSDC > maxCoveragePerRequesterUSDC) reasonCodes.push("REQUESTER_COVERAGE_CAP_EXCEEDED");
  if (verifierOpenCoverageUSDC + requestedCoverageUSDC > maxCoveragePerVerifierUSDC) reasonCodes.push("VERIFIER_COVERAGE_CAP_EXCEEDED");
  if (requestedCoverageUSDC > availablePoolUSDC || requestedCoverageUSDC > maxCoveragePerPoolUSDC) reasonCodes.push("POOL_CAPACITY_INSUFFICIENT");
  const minStakeRatioBps = uintFromUnknown(constraints.minAgentStakeToCoverageRatioBps);
  if (requestedCoverageUSDC > 0n && stakeCapacityUSDC * 10_000n < requestedCoverageUSDC * minStakeRatioBps) reasonCodes.push("STAKE_RATIO_TOO_LOW");
  const feeUSDC = BigInt(decimal(((envelope.economics as JsonObject).verifierFeeUSDC))) + BigInt(decimal(((envelope.economics as JsonObject).requesterCancelBondUSDC)));
  const minFeeRatioBps = uintFromUnknown(constraints.minFeeToCoverageRatioBps);
  if (requestedCoverageUSDC > 0n && feeUSDC * 10_000n < requestedCoverageUSDC * minFeeRatioBps) reasonCodes.push("FEE_RATIO_TOO_LOW");
  if (Array.isArray(scope.verifierAllowlist) && scope.verifierAllowlist.length > 0 && !scope.verifierAllowlist.map(String).includes(String(envelope.verifierId ?? ""))) reasonCodes.push("VERIFIER_NOT_ALLOWED");
  if (Array.isArray(scope.requesterAllowlist) && scope.requesterAllowlist.length > 0 && !scope.requesterAllowlist.map(String).includes(String(envelope.requesterId ?? ""))) reasonCodes.push("REQUESTER_NOT_ALLOWED");
  if ((input.score?.riskBand ?? passport.capacity?.riskBand) === "E") reasonCodes.push("RISK_BAND_TOO_LOW");

  const approvedCoverageUSDC = reasonCodes.length === 0 ? requestedCoverageUSDC.toString() : "0";
  const premiumUSDC = reasonCodes.length === 0 ? (uintFromUnknown(pricing.baseRecourseFeeBps) * requestedCoverageUSDC / 10_000n).toString() : "0";
  return validateAgentBondsRecourseDecision({
    schemaVersion: "agent-bonds-recourse-decision/v1",
    decisionId: `decision_${String(envelope.envelopeId)}`,
    policyId: policy.policyId,
    envelopeId: envelope.envelopeId,
    agentId: passport.agentId,
    requesterId: envelope.requesterId,
    status: reasonCodes.length === 0 ? "approved" : reasonCodes.some((code) => code.includes("NOT_ALLOWED") || code.includes("EXCLUDED") || code.includes("TOO_HIGH") || code.includes("LOW")) ? "denied" : "manual_review",
    requestedCoverageUSDC: requestedCoverageUSDC.toString(),
    approvedCoverageUSDC,
    premiumUSDC,
    reasonCodes: reasonCodes.length === 0 ? ["TASK_CLASS_ALLOWED", "RISK_TIER_ALLOWED", "OBJECTIVE_ACCEPTANCE_CONFIRMED", "STAKE_RATIO_SUFFICIENT"] : reasonCodes,
    inputs: {
      taskClass,
      riskTier,
      agentRiskBand: input.score?.riskBand ?? ((passport.capacity as JsonObject).riskBand ?? "UNRATED"),
      stakeCapacityUSDC: stakeCapacityUSDC.toString(),
      availablePoolUSDC: availablePoolUSDC.toString(),
      currentAgentCoverageUSDC: agentOpenCoverageUSDC.toString(),
      currentRequesterCoverageUSDC: requesterOpenCoverageUSDC.toString(),
      currentVerifierCoverageUSDC: verifierOpenCoverageUSDC.toString(),
    },
    createdAt: new Date().toISOString(),
  });
}

export function buildFailureWaterfall(input: {
  receipt: BondedExecutionReceipt;
  recourseDecision?: AgentBondsRecourseDecision | null;
}): AgentBondsFailureWaterfall {
  const receipt = input.receipt;
  const settlement = (receipt.settlement ?? {}) as JsonObject;
  const terminalState = String(((receipt.lifecycle as JsonObject).terminalState) ?? "unknown");
  const components: JsonObject[] = [];
  const requesterRefundUSDC = decimal(settlement.requesterRefundUSDC);
  const verifierPayoutUSDC = decimal(settlement.verifierPayoutUSDC);
  const slashedUSDC = decimal(settlement.slashedUSDC);
  if (BigInt(requesterRefundUSDC) > 0n) components.push({ source: "requester_escrow", amountUSDC: requesterRefundUSDC, kind: "refund" });
  if (BigInt(slashedUSDC) > 0n) components.push({ source: "agent_bond", amountUSDC: slashedUSDC, kind: "slash" });
  const recourseUSDC = input.recourseDecision?.approvedCoverageUSDC ? decimal(input.recourseDecision.approvedCoverageUSDC) : "0";
  if (BigInt(recourseUSDC) > 0n && ["slashed_invalid", "slashed_timeout", "challenge_upheld"].includes(terminalState)) {
    components.push({ source: "recourse_pool", amountUSDC: recourseUSDC, kind: "recourse" });
  }
  if (BigInt(verifierPayoutUSDC) > 0n) components.push({ source: "requester_escrow", amountUSDC: verifierPayoutUSDC, kind: "fee" });
  return validateAgentBondsFailureWaterfall({
    schemaVersion: "agent-bonds-failure-waterfall/v1",
    waterfallId: stableHash("agent-bonds-failure-waterfall/v1", { receiptId: receipt.receiptId, terminalState, recourseUSDC }),
    receiptId: receipt.receiptId,
    taskId: receipt.taskId,
    terminalState,
    components,
    totals: {
      toRequesterUSDC: addDecimalStrings([requesterRefundUSDC, recourseUSDC]),
      toVerifierUSDC: verifierPayoutUSDC,
      slashedUSDC,
      recourseUSDC,
    },
    createdAt: new Date().toISOString(),
  });
}

export function getApiDataPilotTemplate(): { passport: AgentBondPassport; envelope: BondedTaskEnvelope; policy: AgentBondsRecoursePolicy } {
  return {
    passport: readJson("fixtures/agent-bonds/passports/agent-passport.api-data-pilot.template.json"),
    envelope: readJson("fixtures/agent-bonds/envelopes/bonded-task-envelope.api-data-recourse.template.json"),
    policy: sampleRecoursePolicy(),
  };
}

export function recourseFoundationPresent(): boolean {
  return fileExists(POLICY_SCHEMA) && fileExists(DECISION_SCHEMA) && fileExists(WATERFALL_SCHEMA) && fileExists(POLICY_ATTESTATION_SCHEMA);
}
