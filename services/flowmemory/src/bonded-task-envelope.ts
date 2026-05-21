import { canonicalize, readJson, stableHash, validateWithSchema, type JsonObject } from "./agent-bonds-phase2-shared.ts";

export type BondedTaskEnvelope = JsonObject;
export type EnvelopeQuoteInput = { taskClass?: string; payoutUSDC?: string; riskTier?: number; fundingMode?: string };
export type EnvelopeQuote = JsonObject;
export type ManagerCreateTaskArgs = JsonObject;
export type A2ABondedTaskMessage = JsonObject;
export type MCPBondedToolCall = JsonObject;

const SCHEMA_PATH = "schemas/flowmemory/bonded-task-envelope.schema.json";
const TEMPLATE_PATH = "fixtures/agent-bonds/envelopes/bonded-task-envelope.code-patch.template.json";

export function validateBondedTaskEnvelope(input: unknown): BondedTaskEnvelope {
  return validateWithSchema<BondedTaskEnvelope>(SCHEMA_PATH, input);
}

export function canonicalizeBondedTaskEnvelope(envelope: BondedTaskEnvelope): string {
  return canonicalize(envelope);
}

export function computeEnvelopeHash(envelope: BondedTaskEnvelope): string {
  const clone = structuredClone(envelope);
  clone.envelopeHash = "0x" + "0".repeat(64);
  return stableHash("bonded-task-envelope/v1", clone);
}

export function quoteBondedTaskEnvelope(input: EnvelopeQuoteInput): EnvelopeQuote {
  const template = readJson<BondedTaskEnvelope>(TEMPLATE_PATH);
  const quote = structuredClone(template);
  quote.envelopeId = `quote_${input.taskClass ?? quote.task?.taskClass ?? "task"}`;
  const task = (quote.task ?? {}) as JsonObject;
  task.taskClass = input.taskClass ?? task.taskClass ?? "code.patch";
  quote.task = task;
  const economics = (quote.economics ?? {}) as JsonObject;
  if (input.payoutUSDC !== undefined) {
    economics.payoutUSDC = input.payoutUSDC;
  }
  quote.economics = economics;
  const policy = (quote.policy ?? {}) as JsonObject;
  if (input.riskTier !== undefined) {
    policy.riskTier = input.riskTier;
  }
  quote.policy = policy;
  const payment = (quote.payment ?? {}) as JsonObject;
  if (input.fundingMode !== undefined) {
    payment.fundingMode = input.fundingMode;
  }
  quote.payment = payment;
  quote.envelopeHash = computeEnvelopeHash(quote);
  return validateBondedTaskEnvelope(quote);
}

export function envelopeToAgentBondManagerCreateTaskArgs(envelope: BondedTaskEnvelope): ManagerCreateTaskArgs {
  return {
    schema: "flowmemory.agent_bond_manager_create_task_args.v1",
    requesterId: envelope.requesterId,
    agentId: envelope.agentId ?? null,
    verifierId: envelope.verifierId ?? null,
    confirmingVerifierId: envelope.confirmingVerifierId ?? null,
    taskClass: (envelope.task as JsonObject).taskClass,
    policyId: (envelope.policy as JsonObject).policyId,
    payoutUSDC: (envelope.economics as JsonObject).payoutUSDC,
    agentBondUSDC: (envelope.economics as JsonObject).agentBondUSDC,
    verifierFeeUSDC: (envelope.economics as JsonObject).verifierFeeUSDC,
    requesterCancelBondUSDC: (envelope.economics as JsonObject).requesterCancelBondUSDC,
    disputeBondUSDC: (envelope.economics as JsonObject).disputeBondUSDC,
    evidenceSchema: (envelope.evidence as JsonObject).requiredEvidenceSchema,
    envelopeHash: envelope.envelopeHash,
  };
}

export function envelopeFromA2AMessage(input: A2ABondedTaskMessage): BondedTaskEnvelope {
  const metadata = (input.metadata ?? {}) as JsonObject;
  const embedded = metadata.bondedTaskEnvelope;
  if (typeof embedded === "object" && embedded !== null && !Array.isArray(embedded)) {
    return validateBondedTaskEnvelope(embedded);
  }
  throw new Error("A2A message does not contain bondedTaskEnvelope metadata");
}

export function envelopeFromMCPToolCall(input: MCPBondedToolCall): BondedTaskEnvelope {
  const embedded = input.bondedTaskEnvelope ?? input.envelope;
  if (typeof embedded === "object" && embedded !== null && !Array.isArray(embedded)) {
    return validateBondedTaskEnvelope(embedded);
  }
  throw new Error("MCP tool call does not contain a bonded task envelope");
}
