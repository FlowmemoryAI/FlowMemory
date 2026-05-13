import { DOMAIN_STRINGS, LOCAL_ALPHA_SIGNER_ROLES, TYPE_STRINGS, ZERO_BYTES32 } from "./constants.js";
import { verifyDigest } from "./attestations.js";
import { eip712Digest } from "./flowpulse.js";
import { canonicalJsonHash, domainSeparator, typedHash } from "./hashes.js";
import {
  localSignerId,
  localSignerKeyId,
  validateLocalAlphaObjectDocument
} from "./objects.js";

export function localTransactionPayloadHash(payload) {
  return canonicalJsonHash(payload);
}

export function localTransactionEnvelopeHash({
  chainId,
  nonce,
  signerId,
  signerKeyId,
  signerRole,
  payloadHash,
  issuedAtUnixMs,
  expiresAtUnixMs,
  domainSeparator
}) {
  return typedHash(TYPE_STRINGS.localTransactionEnvelopeV0, [
    ["uint256", chainId],
    ["uint64", nonce],
    ["bytes32", signerId],
    ["bytes32", signerKeyId],
    ["uint8", signerRole],
    ["bytes32", payloadHash],
    ["uint64", issuedAtUnixMs],
    ["uint64", expiresAtUnixMs],
    ["bytes32", domainSeparator]
  ]);
}

export const localTransactionEnvelopeId = localTransactionEnvelopeHash;

export function localTransactionEnvelopePayload(input) {
  const structHash = localTransactionEnvelopeHash(input);
  return {
    structHash,
    signingDigest: eip712Digest(input.domainSeparator, structHash)
  };
}

export function localTransactionEnvelopeInput(envelope) {
  const signer = envelope?.signer ?? {};
  return {
    chainId: envelope.chainId,
    nonce: envelope.nonce,
    signerId: signer.signerId,
    signerKeyId: signer.signerKeyId,
    signerRole: signer.signerRoleCode,
    payloadHash: envelope.payloadHash,
    issuedAtUnixMs: envelope.issuedAtUnixMs,
    expiresAtUnixMs: envelope.expiresAtUnixMs,
    domainSeparator: envelope.domainSeparator
  };
}

export function localTransactionReplayKey(envelope) {
  const signerId = envelope?.signer?.signerId ?? "missing-signer";
  return `${envelope?.chainId}:${envelope?.domain}:${signerId}:${envelope?.nonce}`;
}

export function localSignerRoleCode(role) {
  if (typeof role === "number" || typeof role === "bigint") {
    return Number(role);
  }
  if (typeof role === "string" && /^[0-9]+$/.test(role)) {
    return Number(role);
  }
  const code = LOCAL_ALPHA_SIGNER_ROLES[role];
  if (code === undefined) {
    throw new Error(`unknown signer role: ${role}`);
  }
  return code;
}

export function localSignerPublicMetadata({ publicKey, signerRole = "operator", keyScopeHash }) {
  const signerRoleCode = localSignerRoleCode(signerRole);
  const signerId = localSignerId({ publicKey });
  const signerKeyId = localSignerKeyId({ publicKey, signerRole: signerRoleCode, keyScopeHash });
  return {
    accountId: signerId,
    signerId,
    signerKeyId,
    signerRole: signerRoleName(signerRoleCode),
    signerRoleCode,
    publicKey
  };
}

export function createLocalTransactionEnvelope({
  chainId,
  nonce,
  payload,
  signer,
  issuedAtUnixMs,
  expiresAtUnixMs,
  signature = null
}) {
  const txDomain = DOMAIN_STRINGS.localTransactionEnvelope;
  const txDomainSeparator = domainSeparator("localTransactionEnvelope");
  const payloadHash = localTransactionPayloadHash(payload);
  const input = {
    chainId,
    nonce,
    signerId: signer.signerId,
    signerKeyId: signer.signerKeyId,
    signerRole: signer.signerRoleCode,
    payloadHash,
    issuedAtUnixMs,
    expiresAtUnixMs,
    domainSeparator: txDomainSeparator
  };
  const signing = localTransactionEnvelopePayload(input);

  return {
    schema: "flowchain.local_transaction_envelope.v0",
    envelopeId: signing.structHash,
    domain: txDomain,
    domainSeparator: txDomainSeparator,
    chainId: String(chainId),
    nonce: String(nonce),
    payloadHash,
    payload,
    signer,
    issuedAtUnixMs: String(issuedAtUnixMs),
    expiresAtUnixMs: String(expiresAtUnixMs),
    signingDigest: signing.signingDigest,
    signature
  };
}

export function validateLocalTransactionEnvelope({ envelope, context = {} }) {
  const errors = [];

  if (!envelope || typeof envelope !== "object" || Array.isArray(envelope)) {
    return { valid: false, errors: ["missing-envelope"] };
  }

  if (envelope.schema !== "flowchain.local_transaction_envelope.v0") {
    errors.push("changed-object-type");
  }

  const expectedDomain = DOMAIN_STRINGS.localTransactionEnvelope;
  const expectedDomainSeparator = domainSeparator("localTransactionEnvelope");
  if (envelope.domain !== expectedDomain || envelope.domainSeparator !== expectedDomainSeparator) {
    errors.push("wrong-domain");
  }

  if (context.expectedChainId !== undefined && String(envelope.chainId) !== String(context.expectedChainId)) {
    errors.push("wrong-chain-id");
  }

  if (!isUintString(envelope.chainId) || !isUintString(envelope.nonce)) {
    errors.push("malformed-nonce");
  }

  if (envelope.payloadHash !== localTransactionPayloadHash(envelope.payload)) {
    errors.push("bad-payload-hash");
  }

  const expectedObjectType = envelope.payload?.objectType;
  if (envelope.payload?.object) {
    const objectResult = validateLocalAlphaObjectDocument(envelope.payload.object, { expectedObjectType });
    errors.push(...objectResult.errors);
  }

  const signer = envelope.signer;
  if (!signer || typeof signer !== "object") {
    errors.push("missing-signer");
  } else {
    try {
      const signerRoleCode = localSignerRoleCode(signer.signerRole);
      if (signerRoleCode !== signer.signerRoleCode) {
        errors.push("wrong-signer");
      }
      const expectedSigner = localSignerPublicMetadata({
        publicKey: signer.publicKey,
        signerRole: signerRoleCode
      });
      if (signer.signerId !== expectedSigner.signerId || signer.signerKeyId !== expectedSigner.signerKeyId) {
        errors.push("wrong-signer");
      }
      if (context.expectedSignerId && signer.signerId !== context.expectedSignerId) {
        errors.push("wrong-signer");
      }
      if (signer.signerId === ZERO_BYTES32 || signer.signerKeyId === ZERO_BYTES32) {
        errors.push("missing-signer");
      }
    } catch {
      errors.push("wrong-signer");
    }
  }

  if (context.seenNonces?.has?.(localTransactionReplayKey(envelope))) {
    errors.push("replay");
  }

  try {
    const input = localTransactionEnvelopeInput(envelope);
    const expectedEnvelopeId = localTransactionEnvelopeHash(input);
    const expectedPayload = localTransactionEnvelopePayload(input);
    if (envelope.envelopeId !== expectedEnvelopeId) {
      errors.push("bad-envelope-id");
    }
    if (envelope.signingDigest !== expectedPayload.signingDigest) {
      errors.push("bad-envelope-digest");
    }
    if (
      envelope.signature &&
      envelope.signer?.publicKey &&
      !verifyDigest({
        digest: envelope.signingDigest,
        signature: envelope.signature,
        publicKey: envelope.signer.publicKey
      })
    ) {
      errors.push("bad-signature");
    }
  } catch {
    errors.push("bad-envelope-id");
  }

  if (!envelope.signature) {
    errors.push("missing-signature");
  }

  return {
    valid: errors.length === 0,
    errors: [...new Set(errors)]
  };
}

function signerRoleName(code) {
  for (const [name, value] of Object.entries(LOCAL_ALPHA_SIGNER_ROLES)) {
    if (value === Number(code)) {
      return name;
    }
  }
  throw new Error(`unknown signer role code: ${code}`);
}

function isUintString(value) {
  return typeof value === "string" && /^[0-9]+$/.test(value);
}
