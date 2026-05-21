import { readJson, stableHash, validateWithSchema, type JsonObject } from "./agent-bonds-phase2-shared.ts";
import { listReceiptsForAgent } from "./bonded-execution-receipt.ts";

export type AgentCreditScore = JsonObject;
export type AgentCreditScoreInputs = JsonObject;
export type AgentCreditScoreAttestation = JsonObject;
export type RiskBand = "A" | "B" | "C" | "D" | "E" | "UNRATED";

const SCORE_SCHEMA = "schemas/flowmemory/agent-credit-score.schema.json";
const ATTEST_SCHEMA = "schemas/flowmemory/agent-credit-score-attestation.schema.json";

function clamp(value: number, min: number, max: number): number { return Math.max(min, Math.min(max, value)); }
function wilsonLowerBound(successes: number, trials: number, z = 1.96): number {
  if (trials <= 0) return 0;
  const phat = successes / trials;
  const denominator = 1 + (z * z) / trials;
  const centre = phat + (z * z) / (2 * trials);
  const margin = z * Math.sqrt((phat * (1 - phat) + (z * z) / (4 * trials)) / trials);
  return Math.max(0, (centre - margin) / denominator);
}

function riskBand(score: number): RiskBand {
  if (score >= 850) return "A";
  if (score >= 700) return "B";
  if (score >= 550) return "C";
  if (score >= 400) return "D";
  return score === 0 ? "UNRATED" : "E";
}

export function computeRiskBand(score: number): RiskBand { return riskBand(score); }

export function computeAgentCreditScore(input: AgentCreditScoreInputs): AgentCreditScore {
  const settledTasks = Number(input.settledTasks ?? 0);
  const slashedTasks = Number(input.slashedTasks ?? 0);
  const timeoutTasks = Number(input.timeoutTasks ?? 0);
  const unsupportedTasks = Number(input.unsupportedTasks ?? 0);
  const challengedTasks = Number(input.challengedTasks ?? 0);
  const upheldChallenges = Number(input.upheldChallenges ?? 0);
  const uniqueVerifierCount = Number(input.uniqueVerifierCount ?? 0);
  const totalSettledUSDC = Number(input.totalSettledUSDC ?? 0);
  const n = settledTasks + slashedTasks + timeoutTasks + unsupportedTasks;
  let score = 0;
  if (n > 0) {
    const successLowerBound = wilsonLowerBound(settledTasks, Math.max(1, n));
    const base = 300 + 500 * successLowerBound;
    const valueWeightedExperience = Math.min(100, (Math.log1p(totalSettledUSDC) / Math.log1p(100000)) * 100);
    const verifierDiversity = Math.min(75, Math.sqrt(uniqueVerifierCount) * 15);
    const slashPenalty = 250 * (slashedTasks / Math.max(1, n));
    const timeoutPenalty = 150 * (timeoutTasks / Math.max(1, n));
    const challengePenalty = 125 * (upheldChallenges / Math.max(1, challengedTasks || 1));
    const evidencePenalty = 75 * (unsupportedTasks / Math.max(1, n));
    score = clamp(Math.round(base + valueWeightedExperience + verifierDiversity - slashPenalty - timeoutPenalty - challengePenalty - evidencePenalty), 0, 1000);
  }
  const band = riskBand(score);
  const outputs = {
    bondBpsMultiplier: ({ A: 0.65, B: 0.85, C: 1, D: 1.5, E: 2.5, UNRATED: 1.5 } as Record<RiskBand, number>)[band],
    maxOpenExposureUSDC: ({ A: "1000000000", B: "600000000", C: "300000000", D: "100000000", E: "0", UNRATED: "50000000" } as Record<RiskBand, string>)[band],
    maxTaskPayoutUSDC: ({ A: "100000000", B: "75000000", C: "50000000", D: "10000000", E: "0", UNRATED: "5000000" } as Record<RiskBand, string>)[band],
    confirmingVerifierRequired: !["A", "B"].includes(band),
    underwriterEligible: ["A", "B", "C"].includes(band),
    publicLabel: band,
  };
  return validateWithSchema<AgentCreditScore>(SCORE_SCHEMA, {
    schemaVersion: "agent-credit-score/v1",
    agentId: String(input.agentId ?? "unknown"),
    operatorId: String(input.operatorId ?? "unknown"),
    taskClass: typeof input.taskClass === "string" ? input.taskClass : undefined,
    score,
    riskBand: band,
    computedAt: new Date().toISOString(),
    expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
    inputs: {
      completedTasks: Number(input.completedTasks ?? settledTasks),
      settledTasks,
      challengedTasks,
      upheldChallenges,
      slashedTasks,
      timeoutTasks,
      unsupportedTasks,
      totalSettledUSDC: String(input.totalSettledUSDC ?? "0"),
      totalSlashedUSDC: String(input.totalSlashedUSDC ?? "0"),
      uniqueVerifierCount,
      recentReceiptCount: Number(input.recentReceiptCount ?? 0),
      oldestReceiptAt: input.oldestReceiptAt,
      newestReceiptAt: input.newestReceiptAt,
    },
    components: {
      successLowerBound: n > 0 ? wilsonLowerBound(settledTasks, Math.max(1, n)) : 0,
      valueWeightedExperience: Math.min(100, (Math.log1p(totalSettledUSDC) / Math.log1p(100000)) * 100),
      verifierDiversity: Math.min(75, Math.sqrt(uniqueVerifierCount) * 15),
      slashPenalty: 250 * (slashedTasks / Math.max(1, n || 1)),
      timeoutPenalty: 150 * (timeoutTasks / Math.max(1, n || 1)),
      challengePenalty: 125 * (upheldChallenges / Math.max(1, challengedTasks || 1)),
      evidencePenalty: 75 * (unsupportedTasks / Math.max(1, n || 1)),
      recencyAdjustment: 0,
    },
    outputs,
    reasonCodes: [score === 0 ? "UNRATED_AGENT" : `RISK_BAND_${band}`],
  });
}

export function computeAgentCreditScoreFromReceipts(agentId: string): AgentCreditScore {
  const receipts = listReceiptsForAgent(agentId);
  const settledTasks = receipts.filter((receipt) => ((receipt.lifecycle as JsonObject).terminalState) === "settled_success").length;
  const slashedTasks = receipts.filter((receipt) => String((receipt.lifecycle as JsonObject).terminalState).startsWith("slashed")).length;
  const timeoutTasks = receipts.filter((receipt) => ((receipt.lifecycle as JsonObject).terminalState) === "slashed_timeout").length;
  const unsupportedTasks = receipts.filter((receipt) => ((receipt.lifecycle as JsonObject).terminalState) === "refunded_unsupported").length;
  const challengedTasks = receipts.filter((receipt) => String((receipt.lifecycle as JsonObject).terminalState).includes("challenge")).length;
  const upheldChallenges = receipts.filter((receipt) => ((receipt.lifecycle as JsonObject).terminalState) === "challenge_upheld").length;
  const uniqueVerifierCount = new Set(receipts.map((receipt) => String(((receipt.participants as JsonObject).verifierId) ?? ""))).size;
  const totalSettledUSDC = receipts.reduce((sum, receipt) => sum + BigInt(String(((receipt.settlement as JsonObject).agentPayoutUSDC) ?? "0")), 0n).toString();
  const totalSlashedUSDC = receipts.reduce((sum, receipt) => sum + BigInt(String(((receipt.settlement as JsonObject).slashedUSDC) ?? "0")), 0n).toString();
  return computeAgentCreditScore({ agentId, operatorId: "operator_flowmemory_fixture", settledTasks, slashedTasks, timeoutTasks, unsupportedTasks, challengedTasks, upheldChallenges, uniqueVerifierCount, totalSettledUSDC, totalSlashedUSDC, recentReceiptCount: receipts.length, completedTasks: receipts.length });
}

export function explainCreditScore(score: AgentCreditScore): string[] {
  return [
    `Agent ${String(score.agentId)} is rated ${String(score.riskBand)} with score ${String(score.score)}.`,
    `Confirming verifier required: ${String(((score.outputs as JsonObject).confirmingVerifierRequired) === true)}.`,
  ];
}

export function buildCreditScoreAttestation(score: AgentCreditScore, signer: string): AgentCreditScoreAttestation {
  return validateWithSchema<AgentCreditScoreAttestation>(ATTEST_SCHEMA, {
    schemaVersion: "agent-credit-score-attestation/v1",
    attestationId: `attestation_${String(score.agentId)}_${String(score.riskBand)}`,
    agentId: score.agentId,
    scoreHash: stableHash("agent-credit-score/v1", score),
    score: score.score,
    riskBand: score.riskBand,
    taskClass: score.taskClass,
    validFrom: score.computedAt,
    validUntil: score.expiresAt,
    signer,
    signature: "fixture-signature",
    canonicalPayloadHash: stableHash("agent-credit-score-attestation-payload/v1", { scoreHash: stableHash("agent-credit-score/v1", score), signer }),
  });
}

export function validateCreditScoreAttestation(input: unknown): AgentCreditScoreAttestation {
  return validateWithSchema<AgentCreditScoreAttestation>(ATTEST_SCHEMA, input);
}
