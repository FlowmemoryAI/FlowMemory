import { getAgentBondPassport, type AgentBondPassport } from "./agent-bond-passport.ts";
import { type BondedTaskEnvelope, envelopeFromA2AMessage, validateBondedTaskEnvelope } from "./bonded-task-envelope.ts";
import { readJson, validateWithSchema, type JsonObject } from "./agent-bonds-phase2-shared.ts";

export type A2AAgentCard = JsonObject;
export type A2AAgentBondsExtension = JsonObject;
export type A2AMessage = JsonObject;

const EXTENSION_SCHEMA = "schemas/flowmemory/a2a-agent-bonds-extension.schema.json";
const EXTENSION_URI = "https://flowmemory.ai/a2a/extensions/agent-bonds/v1";

export function buildA2AAgentBondsExtension(passport: AgentBondPassport): A2AAgentBondsExtension {
  return validateA2AAgentBondsExtension({
    uri: EXTENSION_URI,
    description: "FlowMemory Agent Bonds extension for bonded task discovery and execution receipts.",
    required: false,
    params: {
      passportUrl: ((passport.integrations as JsonObject | undefined)?.a2a as JsonObject | undefined)?.agentCardUrl ?? `flowmemory://agent-bonds/passports/${passport.agentId}`,
      envelopeSchemaUrl: "https://flowmemory.ai/schemas/bonded-task-envelope/v1",
      receiptSchemaUrl: "https://flowmemory.ai/schemas/bonded-execution-receipt/v1",
      supportedTaskClasses: Array.isArray(passport.capabilities) ? passport.capabilities.map((capability) => String((capability as JsonObject).taskClass)) : [],
      settlement: {
        chainId: Number(((passport.chain as JsonObject).chainId ?? 8453)),
        caip2: String(((passport.chain as JsonObject).caip2 ?? "eip155:8453")),
        settlementToken: String((((passport.contracts as JsonObject | undefined)?.escrow) ?? "0x0000000000000000000000000000000000000000")),
        settlementTokenSymbol: "USDC",
      },
      bonding: {
        supportsAgentBond: true,
        supportsRequesterBond: true,
        supportsVerifierFee: true,
        supportsDisputeBond: true,
      },
      verification: {
        supportsVerifierReport: true,
        supportsConfirmingVerifier: ((passport.verification as JsonObject).confirmingVerifierRequired) === true,
        supportsChallenge: true,
      },
      x402: {
        supported: (((passport.integrations as JsonObject | undefined)?.x402 as JsonObject | undefined)?.acceptsX402) === true,
        paymentEndpoint: ((passport.integrations as JsonObject | undefined)?.x402 as JsonObject | undefined)?.paymentEndpoint,
      },
    },
  });
}

export function buildA2AAgentCardFromPassport(passport: AgentBondPassport): A2AAgentCard {
  return {
    schemaVersion: "a2a-agent-card/v1",
    name: passport.displayName,
    description: passport.description ?? "FlowMemory Agent Bonds passport-backed agent",
    url: ((passport.integrations as JsonObject | undefined)?.a2a as JsonObject | undefined)?.agentCardUrl ?? null,
    skills: Array.isArray(passport.capabilities)
      ? passport.capabilities.map((capability) => ({
          id: String((capability as JsonObject).taskClass),
          name: String((capability as JsonObject).title),
          description: String((capability as JsonObject).description),
        }))
      : [],
    extensions: [buildA2AAgentBondsExtension(passport)],
  };
}

export function validateA2AAgentBondsExtension(input: unknown): A2AAgentBondsExtension {
  return validateWithSchema<A2AAgentBondsExtension>(EXTENSION_SCHEMA, input);
}

export function extractBondedTaskEnvelopeFromA2AMetadata(input: unknown): BondedTaskEnvelope | null {
  if (typeof input !== "object" || input === null || Array.isArray(input)) return null;
  try {
    return envelopeFromA2AMessage(input as JsonObject);
  } catch {
    return null;
  }
}

export function attachBondedTaskEnvelopeToA2AMessage(message: A2AMessage, envelope: BondedTaskEnvelope): A2AMessage {
  const cloned = structuredClone(message);
  const metadata = ((cloned.metadata ?? {}) as JsonObject);
  metadata.flowmemoryAgentBonds = {
    schemaVersion: "a2a-agent-bonds-metadata/v1",
    envelopeId: envelope.envelopeId,
    envelopeHash: envelope.envelopeHash,
    taskClass: ((envelope.task as JsonObject).taskClass ?? null),
    policyId: ((envelope.policy as JsonObject).policyId ?? null),
    payoutUSDC: ((envelope.economics as JsonObject).payoutUSDC ?? null),
    agentBondUSDC: ((envelope.economics as JsonObject).agentBondUSDC ?? null),
    requiredEvidenceSchema: ((envelope.evidence as JsonObject).requiredEvidenceSchema ?? null),
    receiptExpected: true,
    challengeSupported: true,
  };
  metadata.bondedTaskEnvelope = validateBondedTaskEnvelope(envelope);
  cloned.metadata = metadata;
  return cloned;
}

export function defaultA2AAgentCard(agentId: string): A2AAgentCard | null {
  const passport = getAgentBondPassport(agentId);
  return passport === null ? null : buildA2AAgentCardFromPassport(passport);
}

export function sampleA2AAgentBondsExtension(): A2AAgentBondsExtension {
  return readJson<A2AAgentBondsExtension>("fixtures/agent-bonds/a2a/a2a-agent-bonds-extension.json");
}
