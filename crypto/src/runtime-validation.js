import {
  localTransactionEnvelopeInput,
  localTransactionReplayKey,
  validateLocalTransactionEnvelope
} from "./transactions.js";
import {
  bridgeSourceEventReplayKey,
  flowmemoryTransactionId
} from "./production-network.js";
import {
  flowmemoryAccountId,
  flowmemoryAddressFromPublicKey,
  flowmemoryPublicKeyHash,
  isFlowMemoryRole,
  normalizeFlowMemoryPublicKey
} from "./identity.js";

export function verifyFlowMemoryEnvelope({ document, envelope, context = {} }) {
  const base = validateLocalTransactionEnvelope({
    document,
    envelope,
    context: {
      ...context,
      requireCanonical: context.requireCanonical ?? true
    }
  });
  const failureCodes = new Set(base.errors);

  for (const rootError of malformedRootCodes(document)) {
    failureCodes.add(rootError);
  }

  if (context.seenReplayKeys?.has?.(localTransactionReplayKey(envelope))) {
    failureCodes.add("duplicate-nonce");
  }

  if (context.bridgeSourceEvent && context.seenBridgeSourceEvents?.has?.(bridgeSourceEventReplayKey(context.bridgeSourceEvent))) {
    failureCodes.add("duplicate-bridge-source-event");
  }

  const signerIdentity = deriveSignerIdentity(envelope);
  for (const error of signerIdentity.errors) {
    failureCodes.add(error);
  }

  const transactionId = envelope?.signature ? flowmemoryTransactionId(envelope) : envelope?.transactionId;
  if (context.seenTransactionIds?.has?.(transactionId)) {
    failureCodes.add("duplicate-tx-id");
  }

  const payload = safeEnvelopePayload(envelope);

  return {
    schema: "flowmemory.runtime_verify_result.v0",
    ok: failureCodes.size === 0,
    failureCodes: [...failureCodes],
    signerAddress: signerIdentity.address,
    signerAccountId: signerIdentity.accountId,
    signerPublicIdentity: signerIdentity.publicIdentity,
    payloadHash: envelope?.payloadHash,
    transactionId,
    envelopeId: envelope?.envelopeId,
    signingDigest: envelope?.signingDigest,
    nonce: envelope?.nonce,
    chainId: envelope?.chainId,
    networkProfile: envelope?.networkProfile,
    payloadType: envelope?.payloadType,
    signerRole: envelope?.signerRole,
    signerKeyId: envelope?.signerKeyId,
    envelopePayload: payload
  };
}

function deriveSignerIdentity(envelope) {
  const errors = [];
  if (!envelope?.publicKey) {
    return { errors: ["missing-signer"] };
  }
  try {
    const publicKey = normalizeFlowMemoryPublicKey(envelope.publicKey);
    const address = flowmemoryAddressFromPublicKey(publicKey);
    const accountId = isFlowMemoryRole(envelope.signerRole)
      ? flowmemoryAccountId({ publicKey, role: envelope.signerRole })
      : envelope.signerId;
    return {
      errors,
      address,
      accountId,
      publicIdentity: {
        schema: "flowmemory.runtime_public_identity.v0",
        publicKey,
        publicKeyHash: flowmemoryPublicKeyHash(publicKey),
        address,
        accountId,
        signerRole: envelope.signerRole,
        signerRoleCode: envelope.signerRoleCode,
        signerKeyId: envelope.signerKeyId
      }
    };
  } catch {
    return { errors: ["malformed-public-key"] };
  }
}

function malformedRootCodes(document) {
  if (!document || typeof document !== "object") {
    return [];
  }
  const errors = [];
  for (const [key, value] of Object.entries(document)) {
    if (key.toLowerCase().includes("root") && typeof value === "string" && !/^0x[0-9a-fA-F]{64}$/.test(value)) {
      errors.push("malformed-root");
    }
  }
  return errors;
}

function safeEnvelopePayload(envelope) {
  try {
    return localTransactionEnvelopeInput(envelope);
  } catch {
    return null;
  }
}
