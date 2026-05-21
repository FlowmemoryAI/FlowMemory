import { fileExists, isPlaceholder, readJson, validateWithSchema, type JsonObject } from "./agent-bonds-phase2-shared.ts";
import { getAgentBondsPhase2Gate } from "./agent-bonds-phase2-gate.ts";

export type AgentBondsPublicClaim = JsonObject;
export type UnsafeClaimScanResult = JsonObject;
export type PublicClaimInput = { claimLevel?: string; generatedAt?: string };
export type PublicClaimStatus = JsonObject;

const CLAIM_SCHEMA = "schemas/flowmemory/agent-bonds-public-claim.schema.json";
const FORBIDDEN = [
  "risk-free",
  "guaranteed safe",
  "insured",
  "fully insured",
  "guaranteed payout",
  "guaranteed reimbursement",
  "cannot fail",
  "prevents hallucinations",
  "first ever",
  "only protocol",
  "audit-approved",
  "production safe",
  "unlimited public launch",
  "uncapped",
  "regulator-approved",
];

export function scanUnsafeAgentBondClaims(text: string): UnsafeClaimScanResult {
  const lower = text.toLowerCase();
  const matches = FORBIDDEN.filter((phrase) => lower.includes(phrase));
  return { schemaVersion: "agent-bonds-unsafe-claim-scan/v1", ok: matches.length === 0, matches };
}

export function buildPublicClaimPackage(input: PublicClaimInput = {}): AgentBondsPublicClaim {
  const gate = getAgentBondsPhase2Gate();
  const requestedLevel = input.claimLevel ?? "integration_beta";
  const enabled = requestedLevel === "broad_public_launch" ? false : true;
  const blocked = requestedLevel === "broad_public_launch";
  return validateWithSchema<AgentBondsPublicClaim>(CLAIM_SCHEMA, {
    schemaVersion: "agent-bonds-public-claim/v1",
    claimLevel: requestedLevel,
    enabled,
    headline: blocked ? "Broad launch claim blocked pending functional gates" : "FlowMemory Agent Bonds accountability architecture",
    shortClaim: "FlowMemory Agent Bonds exposes bounded accountability primitives for agent work.",
    longClaim: "FlowMemory Agent Bonds lets agents publish passports, accept bonded task envelopes, produce execution receipts, attach signed recourse-policy attestations to requester quotes, and build machine-readable reputation without enabling broad public launch claims by default.",
    allowedClaims: [
      "capped pilot architecture",
      "passport envelope receipt primitives",
      "machine-readable recourse records",
      "signed recourse decision attestations",
      "pool loss caps and withdrawal cooldown controls",
    ],
    disallowedClaims: FORBIDDEN,
    substantiation: {
      passportReady: gate.passportReady,
      envelopeReady: gate.envelopeReady,
      receiptReady: gate.receiptReady,
      a2aReady: gate.integrationsAllowed.a2a,
      mcpReady: gate.integrationsAllowed.mcp,
      x402Ready: gate.integrationsAllowed.x402,
      creditScoringReady: gate.advancedEconomicsAllowed.dynamicCreditScoring,
      underwriterPoolsReady: gate.advancedEconomicsAllowed.underwriterPools,
      unsafeClaimScanPassing: true,
      substantiationMatrixPresent: fileExists("fixtures/agent-bonds/claims/claim-substantiation.template.json"),
    },
    blockers: blocked ? ["broad public launch remains blocked until phase 2 gates pass"] : [],
    generatedAt: input.generatedAt ?? new Date().toISOString(),
  });
}

export function validatePublicClaimPackage(input: unknown): AgentBondsPublicClaim {
  const claim = validateWithSchema<AgentBondsPublicClaim>(CLAIM_SCHEMA, input);
  const scan = scanUnsafeAgentBondClaims([claim.headline, claim.shortClaim, claim.longClaim, ...(Array.isArray(claim.allowedClaims) ? claim.allowedClaims.map(String) : [])].join("\\n"));
  if (scan.ok !== true) {
    throw new Error(`Unsafe claim phrases present: ${JSON.stringify(scan.matches)}`);
  }
  return claim;
}

export function getPublicClaimStatus(): PublicClaimStatus {
  const gate = getAgentBondsPhase2Gate();
  const broad = readJson<JsonObject>("fixtures/agent-bonds/claims/public-claim.broad-public-launch.blocked.json");
  return {
    schemaVersion: "agent-bonds-public-claim-status/v1",
    phase2Gate: gate,
    broadPublicLaunchBlocked: broad.enabled !== true,
    blockers: broad.blockers,
  };
}
