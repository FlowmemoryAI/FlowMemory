import { canonicalize, listJson, stableHash, validateWithSchema, type JsonObject } from "./agent-bonds-phase2-shared.ts";

export type BondedExecutionReceipt = JsonObject;
export type ReputationDelta = JsonObject;
export type TaskLifecycleSnapshot = JsonObject;

const SCHEMA_PATH = "schemas/flowmemory/bonded-execution-receipt.schema.json";
const RECEIPT_DIR = "fixtures/agent-bonds/receipts";

export function validateBondedExecutionReceipt(input: unknown): BondedExecutionReceipt {
  return validateWithSchema<BondedExecutionReceipt>(SCHEMA_PATH, input);
}

export function canonicalizeBondedExecutionReceipt(receipt: BondedExecutionReceipt): string {
  return canonicalize(receipt);
}

export function computeReceiptHash(receipt: BondedExecutionReceipt): string {
  const clone = structuredClone(receipt);
  clone.receiptHash = "0x" + "0".repeat(64);
  return stableHash("bonded-execution-receipt/v1", clone);
}

function receipts(): BondedExecutionReceipt[] {
  return listJson<BondedExecutionReceipt>(RECEIPT_DIR)
    .filter((receipt) => receipt.schemaVersion === "bonded-execution-receipt/v1")
    .map(validateBondedExecutionReceipt);
}

export function receiptFromTaskLifecycle(input: TaskLifecycleSnapshot): BondedExecutionReceipt {
  return validateBondedExecutionReceipt(input);
}

export function receiptToPassportReputationDelta(receipt: BondedExecutionReceipt): ReputationDelta {
  const agent = ((receipt.reputationDelta ?? {}) as JsonObject).agent as JsonObject;
  const verifier = ((receipt.reputationDelta ?? {}) as JsonObject).verifier as JsonObject | undefined;
  return {
    schema: "flowmemory.agent_bond_reputation_delta.v1",
    receiptId: receipt.receiptId,
    agentId: ((receipt.participants ?? {}) as JsonObject).agentId,
    verifierId: ((receipt.participants ?? {}) as JsonObject).verifierId ?? null,
    agent,
    verifier: verifier ?? null,
  };
}

export function listReceiptsForAgent(agentId: string): BondedExecutionReceipt[] {
  return receipts().filter((receipt) => ((receipt.participants ?? {}) as JsonObject).agentId === agentId);
}

export function listReceiptsForEnvelope(envelopeHash: string): BondedExecutionReceipt[] {
  return receipts().filter((receipt) => receipt.envelopeHash === envelopeHash || receipt.envelopeId === envelopeHash);
}
