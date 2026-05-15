import {
  FlowChainMalformedEnvelopeError,
  FlowChainUnsignedEnvelopeError,
} from "./errors.ts";
import { assertNoFlowChainSecrets } from "./redaction.ts";
import type { FlowChainSignedEnvelope, JsonObject, JsonValue } from "./types.ts";

function isObject(value: unknown): value is JsonObject {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function hasSignature(value: JsonValue | undefined): boolean {
  if (typeof value === "string") {
    return value.trim().length > 0;
  }
  if (isObject(value)) {
    return Object.keys(value).length > 0;
  }
  return false;
}

export function validateSignedEnvelope(value: unknown): FlowChainSignedEnvelope {
  if (!isObject(value)) {
    throw new FlowChainMalformedEnvelopeError("FlowChain signed envelope must be an object.");
  }
  if (typeof value.schema !== "string" || value.schema.length === 0) {
    throw new FlowChainMalformedEnvelopeError("FlowChain signed envelope requires a schema string.");
  }
  if (!isObject(value.tx)) {
    throw new FlowChainMalformedEnvelopeError("FlowChain signed envelope requires a tx object.");
  }
  if (!hasSignature(value.signature)) {
    throw new FlowChainUnsignedEnvelopeError();
  }
  assertNoFlowChainSecrets(value);
  return value as FlowChainSignedEnvelope;
}

export function createLocalSignedEnvelope(tx: JsonObject, signer = "local-sdk-devkit"): FlowChainSignedEnvelope {
  if (!isObject(tx)) {
    throw new FlowChainMalformedEnvelopeError("FlowChain local transaction must be an object.");
  }
  const txType = typeof tx.type === "string" ? tx.type : "UnknownLocalTransaction";
  return validateSignedEnvelope({
    schema: "flowchain.local_transaction_envelope.v0",
    tx,
    signature: {
      scheme: "local-dev-signature-placeholder",
      signer,
      digest: `local-dev-digest:${txType}`,
    },
  });
}
