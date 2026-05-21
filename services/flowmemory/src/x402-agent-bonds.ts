import { readJson, stableHash, validateWithSchema, type JsonObject } from "./agent-bonds-phase2-shared.ts";
import type { BondedTaskEnvelope } from "./bonded-task-envelope.ts";

export type X402AgentBondsPaymentIntent = JsonObject;
export type X402ServicePaymentInput = { description?: string; amountAtomic?: string; payTo?: string };
export type X402PaymentReceipt = JsonObject;
export type X402EnvelopeFundingLink = JsonObject;

const SCHEMA_PATH = "schemas/flowmemory/x402-agent-bonds-payment-intent.schema.json";
const ESCROW_TEMPLATE = "fixtures/agent-bonds/x402/payment-intent.escrow-bridge.json";
const SERVICE_TEMPLATE = "fixtures/agent-bonds/x402/payment-intent.service-payment.json";

export function createX402ServicePaymentIntent(input: X402ServicePaymentInput): X402AgentBondsPaymentIntent {
  const intent = readJson<X402AgentBondsPaymentIntent>(SERVICE_TEMPLATE);
  if (input.description) intent.description = input.description;
  if (input.amountAtomic) ((intent.amount as JsonObject).atomic = input.amountAtomic);
  if (input.payTo) intent.payTo = input.payTo;
  intent.paymentIntentId = `service_${String(Date.now())}`;
  return validateWithSchema<X402AgentBondsPaymentIntent>(SCHEMA_PATH, intent);
}

export function createX402EscrowBridgeIntent(envelope: BondedTaskEnvelope): X402AgentBondsPaymentIntent {
  const intent = readJson<X402AgentBondsPaymentIntent>(ESCROW_TEMPLATE);
  intent.envelopeId = envelope.envelopeId;
  intent.envelopeHash = envelope.envelopeHash;
  intent.description = `Fund bonded task envelope ${String(envelope.envelopeId)}`;
  return validateWithSchema<X402AgentBondsPaymentIntent>(SCHEMA_PATH, intent);
}

export function buildX402PaymentRequiredPayload(intent: X402AgentBondsPaymentIntent): unknown {
  return readJson("fixtures/agent-bonds/x402/payment-required.escrow-bridge.json");
}

export function validateX402PaymentReceipt(input: unknown): X402PaymentReceipt {
  if (typeof input !== "object" || input === null || Array.isArray(input)) {
    throw new Error("x402 payment receipt must be an object");
  }
  return input as X402PaymentReceipt;
}

export function linkX402PaymentToEnvelope(intent: X402AgentBondsPaymentIntent, envelope: BondedTaskEnvelope): X402EnvelopeFundingLink {
  return {
    schemaVersion: "x402-agent-bonds-envelope-link/v1",
    paymentIntentId: intent.paymentIntentId,
    envelopeId: envelope.envelopeId,
    envelopeHash: envelope.envelopeHash,
    fundingMode: ((envelope.payment as JsonObject).fundingMode ?? intent.mode),
    linkHash: stableHash("x402-agent-bonds-envelope-link/v1", { paymentIntentId: intent.paymentIntentId, envelopeHash: envelope.envelopeHash }),
  };
}
