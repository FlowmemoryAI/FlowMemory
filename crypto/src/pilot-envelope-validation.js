import { validateLocalTransactionEnvelope, localTransactionReplayKey } from "./transactions.js";

export const PILOT_MESSAGE_SCHEMAS = Object.freeze([
  "flowmemory.pilot_bridge_credit_ack.v0",
  "flowmemory.pilot_withdrawal_intent.v0",
  "flowmemory.pilot_release_evidence.v0",
  "flowmemory.pilot_emergency_control.v0"
]);

export function validatePilotOperatorEnvelope({ document, envelope, context = {} }) {
  const errors = new Set();

  if (!document || typeof document !== "object") {
    return { valid: false, errors: ["wrong-object-type"] };
  }
  if (!PILOT_MESSAGE_SCHEMAS.includes(document.schema)) {
    return { valid: false, errors: ["wrong-object-type"] };
  }

  if (!hasPilotCapFields(document.pilotCap)) {
    errors.add("missing-cap-fields");
  }

  const base = validateLocalTransactionEnvelope({
    document,
    envelope,
    context: {
      chainId: context.chainId ?? context.expectedChainId,
      expectedNonce: context.expectedNonce,
      expectedSignerId: context.expectedSignerId ?? context.expectedOperatorId,
      seenNonces: context.seenNonces
    }
  });
  for (const error of base.errors) {
    errors.add(error);
  }

  const expectedChainId = context.chainId ?? context.expectedChainId;
  const documentChainId = document.chainId ?? document.sourceChainId;
  if (expectedChainId !== undefined && String(documentChainId) !== String(expectedChainId)) {
    errors.add("wrong-chain-id");
  }

  if (
    context.expectedDestinationChainId !== undefined &&
    String(document.destinationChainId) !== String(context.expectedDestinationChainId)
  ) {
    errors.add("wrong-chain-id");
  }

  if (
    context.expectedContractAddress &&
    normalizeAddress(document.contractAddress) !== normalizeAddress(context.expectedContractAddress)
  ) {
    errors.add("wrong-contract-address");
  }

  if (context.expectedOperatorId && document.operatorId !== context.expectedOperatorId) {
    errors.add("wrong-operator");
  }

  if (envelope?.signerId && document.operatorId && envelope.signerId !== document.operatorId) {
    errors.add("wrong-operator");
  }

  if (envelope?.signerRole && envelope.signerRole !== "operator") {
    errors.add("wrong-operator");
  }

  try {
    if (BigInt(document.expiresAtUnixMs) < BigInt(document.issuedAtUnixMs)) {
      errors.add("expired-message");
    }
    if (context.nowUnixMs !== undefined && BigInt(document.expiresAtUnixMs) < BigInt(context.nowUnixMs)) {
      errors.add("expired-message");
    }
    if (
      context.nowUnixMs !== undefined &&
      document.pilotCap?.windowEndsAtUnixMs !== undefined &&
      BigInt(document.pilotCap.windowEndsAtUnixMs) < BigInt(context.nowUnixMs)
    ) {
      errors.add("expired-message");
    }
  } catch {
    errors.add("invalid-message-time");
  }

  return {
    valid: errors.size === 0,
    errors: [...errors]
  };
}

export function pilotEnvelopeReplayKey(envelope) {
  return localTransactionReplayKey(envelope);
}

export function assertPublicPilotMetadataContainsNoSecrets(value) {
  const serialized = JSON.stringify(value);
  if (
    /privateKey|private_key|seedPhrase|seed phrase|mnemonic|ciphertext|authTag|password|rpc[-_]?credential|rpc[-_]?url|api[-_]?key|webhook/i.test(serialized) ||
    /https:\/\/hooks\.slack\.com|https:\/\/discord\.com\/api\/webhooks/i.test(serialized)
  ) {
    throw new Error("public pilot metadata contains secret-shaped material");
  }
}

function hasPilotCapFields(cap) {
  if (!cap || typeof cap !== "object") {
    return false;
  }
  const required = [
    "capId",
    "assetId",
    "maxAmount",
    "usedAmount",
    "unit",
    "windowStartsAtUnixMs",
    "windowEndsAtUnixMs",
    "realValuePilot",
    "productionReady"
  ];
  if (required.some((field) => cap[field] === undefined || cap[field] === null || cap[field] === "")) {
    return false;
  }
  try {
    return (
      isHex32(cap.capId) &&
      isHex32(cap.assetId) &&
      BigInt(cap.maxAmount) > 0n &&
      BigInt(cap.usedAmount) >= 0n &&
      BigInt(cap.usedAmount) <= BigInt(cap.maxAmount) &&
      BigInt(cap.windowEndsAtUnixMs) > BigInt(cap.windowStartsAtUnixMs) &&
      cap.realValuePilot === true &&
      cap.productionReady === false
    );
  } catch {
    return false;
  }
}

function normalizeAddress(value) {
  return typeof value === "string" ? value.toLowerCase() : value;
}

function isHex32(value) {
  return typeof value === "string" && /^0x[0-9a-fA-F]{64}$/.test(value);
}
