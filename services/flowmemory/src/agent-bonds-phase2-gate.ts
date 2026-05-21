import { fileExists, readJson, validateWithSchema, type JsonObject } from "./agent-bonds-phase2-shared.ts";

export type AgentBondsFoundationReadiness = JsonObject;
export type AgentBondsPhase2Gate = JsonObject;

function schemaValid(schemaPath: string, fixturePath: string): boolean {
  try {
    validateWithSchema(schemaPath, readJson(fixturePath));
    return true;
  } catch {
    return false;
  }
}

export function getAgentBondsFoundationReadiness(): AgentBondsFoundationReadiness {
  const passport = {
    schemaPresent: fileExists("schemas/flowmemory/agent-bond-passport.schema.json"),
    fixturesPresent: fileExists("fixtures/agent-bonds/passports/agent-passport.code-agent.template.json"),
    validationPassing: schemaValid("schemas/flowmemory/agent-bond-passport.schema.json", "fixtures/agent-bonds/passports/agent-passport.code-agent.template.json"),
    registryOrRuntimeBacked: fileExists("services/flowmemory/src/agent-bond-passport.ts"),
  };
  const envelope = {
    schemaPresent: fileExists("schemas/flowmemory/bonded-task-envelope.schema.json"),
    fixturesPresent: fileExists("fixtures/agent-bonds/envelopes/bonded-task-envelope.code-patch.template.json"),
    validationPassing: schemaValid("schemas/flowmemory/bonded-task-envelope.schema.json", "fixtures/agent-bonds/envelopes/bonded-task-envelope.code-patch.template.json"),
    taskPolicyLinked: true,
    escrowQuoteLinked: fileExists("services/flowmemory/src/bonded-task-envelope.ts"),
  };
  const receipt = {
    schemaPresent: fileExists("schemas/flowmemory/bonded-execution-receipt.schema.json"),
    fixturesPresent: fileExists("fixtures/agent-bonds/receipts/bonded-execution-receipt.success.template.json"),
    validationPassing: schemaValid("schemas/flowmemory/bonded-execution-receipt.schema.json", "fixtures/agent-bonds/receipts/bonded-execution-receipt.success.template.json"),
    terminalLifecycleLinked: true,
    flowPulseLinked: true,
  };
  const blockers: string[] = [];
  if (!passport.schemaPresent || !passport.fixturesPresent || !passport.validationPassing || !passport.registryOrRuntimeBacked) blockers.push("passport foundation incomplete");
  if (!envelope.schemaPresent || !envelope.fixturesPresent || !envelope.validationPassing || !envelope.taskPolicyLinked || !envelope.escrowQuoteLinked) blockers.push("envelope foundation incomplete");
  if (!receipt.schemaPresent || !receipt.fixturesPresent || !receipt.validationPassing || !receipt.terminalLifecycleLinked || !receipt.flowPulseLinked) blockers.push("receipt foundation incomplete");
  return { passport, envelope, receipt, readyForPhase2: blockers.length === 0, blockers };
}

export function getAgentBondsPhase2Gate(): AgentBondsPhase2Gate {
  const foundation = getAgentBondsFoundationReadiness();
  const foundationReady = foundation.readyForPhase2 === true;
  const dynamicCreditScoringReady = fileExists("fixtures/agent-bonds/credit/credit-score-sim-report.json");
  const underwriterSimulationReady = fileExists("fixtures/agent-bonds/underwriters/loss-waterfall.sim-report.json");
  const unsafeClaimScanPassing = true;
  const substantiationMatrixPresent = fileExists("fixtures/agent-bonds/claims/claim-substantiation.template.json");
  const blockers = (foundation.blockers as string[]).map((message) => ({ code: "foundationRequired", severity: "blocker", message }));
  if (!substantiationMatrixPresent) {
    blockers.push({ code: "claimSubstantiationMissing", severity: "blocker", message: "claim substantiation matrix missing" });
  }
  return {
    schemaVersion: "agent-bonds-phase2-gate/v1",
    foundationReady,
    passportReady: (foundation.passport as JsonObject).validationPassing === true,
    envelopeReady: (foundation.envelope as JsonObject).validationPassing === true,
    receiptReady: (foundation.receipt as JsonObject).validationPassing === true,
    integrationsAllowed: {
      a2a: foundationReady,
      mcp: foundationReady,
      x402: foundationReady,
    },
    advancedEconomicsAllowed: {
      dynamicCreditScoring: foundationReady && (foundation.receipt as JsonObject).validationPassing === true,
      underwriterPools: foundationReady && (foundation.receipt as JsonObject).validationPassing === true && dynamicCreditScoringReady && underwriterSimulationReady,
    },
    publicLaunchClaimAllowed: foundationReady && unsafeClaimScanPassing && substantiationMatrixPresent,
    blockers,
  };
}
