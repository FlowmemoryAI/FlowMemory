import { canonicalJson, keccak256Hex } from "../../shared/src/index.ts";
import type { JsonObject, JsonValue } from "./types.ts";

export const FLOWCHAIN_SIGNED_ENVELOPE_V1 = "flowchain.signed_transaction_envelope.v1";
export const FLOWCHAIN_TRANSFER_PAYLOAD_V1 = "flowchain.transaction.transfer.v1";
export const FLOWCHAIN_LOCAL_SIGNATURE_SCHEME_V1 = "flowchain-local-digest-v1";

export interface SignedEnvelopeValidation {
  envelope: JsonObject;
  chainId: string;
  signer: string;
  nonce: string;
  txId: string;
  payload: JsonObject;
  payloadSummary: JsonObject;
  signatureVerification: JsonObject;
}

export interface SignedEnvelopeValidationFailure {
  code:
    | "UNSIGNED_TRANSACTION"
    | "BAD_SIGNATURE"
    | "WRONG_CHAIN_ID"
    | "MALFORMED_REQUEST";
  message: string;
  details?: JsonValue;
}

function asObject(value: JsonValue | undefined): JsonObject | null {
  return value !== null && typeof value === "object" && !Array.isArray(value) ? value as JsonObject : null;
}

function stringValue(value: JsonValue | undefined): string | null {
  if (typeof value === "string") {
    return value;
  }
  if (typeof value === "number" || typeof value === "boolean") {
    return String(value);
  }
  return null;
}

function hashJson(schema: string, value: JsonValue): string {
  return keccak256Hex(new TextEncoder().encode(canonicalJson({ schema, value })));
}

function signatureValue(envelope: JsonObject): string | null {
  const signature = envelope.signature;
  if (typeof signature === "string") {
    return signature;
  }
  const signatureObject = asObject(signature);
  return signatureObject === null ? null : stringValue(signatureObject.value);
}

function signingPayload(envelope: JsonObject): JsonObject {
  return {
    schema: "flowchain.signed_transaction_payload.v1",
    chainId: stringValue(envelope.chainId),
    signer: stringValue(envelope.signer),
    nonce: stringValue(envelope.nonce),
    payload: asObject(envelope.payload),
  };
}

export function localSignatureDigest(envelope: JsonObject): string {
  return hashJson(FLOWCHAIN_LOCAL_SIGNATURE_SCHEME_V1, signingPayload(envelope));
}

export function signedEnvelopeTxId(envelope: JsonObject): string {
  return hashJson("flowchain.signed_transaction.tx_id.v1", signingPayload(envelope));
}

function payloadSummary(payload: JsonObject): JsonObject {
  return {
    schema: "flowmemory.control_plane.transaction_payload_summary.v1",
    payloadSchema: stringValue(payload.schema),
    type: stringValue(payload.type) ?? stringValue(payload.action) ?? "unknown",
    from: stringValue(payload.from) ?? stringValue(payload.accountId) ?? null,
    to: stringValue(payload.to) ?? stringValue(payload.recipient) ?? null,
    tokenId: stringValue(payload.tokenId) ?? stringValue(payload.assetId) ?? "local-test-unit",
    amount: stringValue(payload.amount) ?? stringValue(payload.units) ?? null,
  };
}

function validatePayload(payload: JsonObject): SignedEnvelopeValidationFailure | null {
  const payloadSchema = stringValue(payload.schema);
  if (payloadSchema === null || !/^(flowchain|flowmemory)\.[a-z0-9_.-]+\.v[0-9]+$/.test(payloadSchema)) {
    return {
      code: "MALFORMED_REQUEST",
      message: "signed transaction payload requires a versioned flowchain/flowmemory schema",
      details: { payloadSchema },
    };
  }

  if (payloadSchema === FLOWCHAIN_TRANSFER_PAYLOAD_V1 || stringValue(payload.type) === "transfer") {
    const from = stringValue(payload.from);
    const to = stringValue(payload.to);
    const amount = stringValue(payload.amount);
    if (from === null || to === null || amount === null || !/^[0-9]+$/.test(amount) || BigInt(amount) <= 0n) {
      return {
        code: "MALFORMED_REQUEST",
        message: "transfer payload requires from, to, and a positive integer amount",
        details: { payloadSchema },
      };
    }
  }

  return null;
}

export function validateSignedEnvelope(
  envelope: JsonObject,
  expectedChainId: string,
): SignedEnvelopeValidation | SignedEnvelopeValidationFailure {
  const schema = stringValue(envelope.schema);
  if (schema !== FLOWCHAIN_SIGNED_ENVELOPE_V1) {
    return {
      code: "UNSIGNED_TRANSACTION",
      message: "transaction_submit accepts only versioned FlowChain signed envelopes",
      details: { schema },
    };
  }

  const chainId = stringValue(envelope.chainId);
  const signer = stringValue(envelope.signer);
  const nonce = stringValue(envelope.nonce);
  const payload = asObject(envelope.payload);
  const signature = signatureValue(envelope);
  const signatureScheme = stringValue(envelope.signatureScheme) ?? FLOWCHAIN_LOCAL_SIGNATURE_SCHEME_V1;

  if (chainId === null || signer === null || nonce === null || payload === null || signature === null) {
    return {
      code: "UNSIGNED_TRANSACTION",
      message: "signed envelope requires chainId, signer, nonce, payload, and signature",
      details: { schema },
    };
  }

  if (chainId !== expectedChainId) {
    return {
      code: "WRONG_CHAIN_ID",
      message: `signed envelope chainId ${chainId} does not match ${expectedChainId}`,
      details: { expectedChainId, actualChainId: chainId },
    };
  }

  if (!/^0x[0-9a-fA-F]{40}$/.test(signer) && !/^0x[0-9a-fA-F]{64}$/.test(signer)) {
    return {
      code: "MALFORMED_REQUEST",
      message: "signed envelope signer must be a 20-byte or 32-byte hex identifier",
      details: { signer },
    };
  }

  if (!/^[0-9]+$/.test(nonce)) {
    return {
      code: "MALFORMED_REQUEST",
      message: "signed envelope nonce must be a non-negative integer string",
      details: { nonce },
    };
  }

  const payloadFailure = validatePayload(payload);
  if (payloadFailure !== null) {
    return payloadFailure;
  }

  if (signatureScheme !== FLOWCHAIN_LOCAL_SIGNATURE_SCHEME_V1) {
    return {
      code: "BAD_SIGNATURE",
      message: "signed envelope uses an unsupported local signature scheme",
      details: { signatureScheme },
    };
  }

  const expectedSignature = localSignatureDigest(envelope);
  if (signature !== expectedSignature) {
    return {
      code: "BAD_SIGNATURE",
      message: "signed envelope signature verification failed",
      details: {
        signatureScheme,
        expectedDigest: expectedSignature,
      },
    };
  }

  return {
    envelope,
    chainId,
    signer,
    nonce,
    txId: signedEnvelopeTxId(envelope),
    payload,
    payloadSummary: payloadSummary(payload),
    signatureVerification: {
      schema: "flowmemory.control_plane.signature_verification.v1",
      scheme: signatureScheme,
      verified: true,
      digest: expectedSignature,
    },
  };
}

export function buildLocalSignedTransferEnvelope(options: {
  chainId: string;
  signer: string;
  nonce: string;
  from: string;
  to: string;
  tokenId?: string;
  amount: string;
  memo?: string;
}): JsonObject {
  const envelope: JsonObject = {
    schema: FLOWCHAIN_SIGNED_ENVELOPE_V1,
    chainId: options.chainId,
    signer: options.signer,
    nonce: options.nonce,
    signatureScheme: FLOWCHAIN_LOCAL_SIGNATURE_SCHEME_V1,
    payload: {
      schema: FLOWCHAIN_TRANSFER_PAYLOAD_V1,
      type: "transfer",
      from: options.from,
      to: options.to,
      tokenId: options.tokenId ?? "local-test-unit",
      amount: options.amount,
      memo: options.memo,
    },
  };
  envelope.signature = localSignatureDigest(envelope);
  return envelope;
}
