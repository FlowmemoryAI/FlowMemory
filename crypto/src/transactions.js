import { DOMAIN_STRINGS, LOCAL_ALPHA_SIGNER_ROLES, TYPE_STRINGS, ZERO_BYTES32 } from "./constants.js";
import { verifyDigest } from "./attestations.js";
import { eip712Digest } from "./flowpulse.js";
import { canonicalJsonHash, domainSeparator, keccakUtf8, typedHash } from "./hashes.js";
import {
  localAlphaObjectDescriptor,
  localAlphaObjectId,
  localAlphaObjectTypeHash
} from "./objects.js";

export function localTransactionEnvelopeHash({
  chainId,
  domainSeparator,
  signerId,
  signerKeyId,
  signerRole,
  nonce,
  payloadHash,
  objectId,
  objectTypeHash,
  issuedAtUnixMs
}) {
  return typedHash(TYPE_STRINGS.localTransactionEnvelopeV0, [
    ["uint256", chainId],
    ["bytes32", domainSeparator],
    ["bytes32", signerId],
    ["bytes32", signerKeyId],
    ["uint8", signerRole],
    ["uint64", nonce],
    ["bytes32", payloadHash],
    ["bytes32", objectId],
    ["bytes32", objectTypeHash],
    ["uint64", issuedAtUnixMs]
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
  return {
    chainId: envelope.chainId,
    domainSeparator: envelope.domainSeparator,
    signerId: envelope.signerId,
    signerKeyId: envelope.signerKeyId,
    signerRole: envelope.signerRoleCode,
    nonce: envelope.nonce,
    payloadHash: envelope.payloadHash,
    objectId: envelope.objectId,
    objectTypeHash: envelope.objectTypeHash,
    issuedAtUnixMs: envelope.issuedAtUnixMs
  };
}

export function localTransactionReplayKey(envelope) {
  return `${envelope.chainId}:${envelope.domain}:${envelope.signerId}:${envelope.nonce}`;
}

export function localTransactionDomain(chainId) {
  return `${DOMAIN_STRINGS.localTransactionEnvelope}:chain:${chainId}`;
}

export function localTransactionDomainSeparator(chainId) {
  return keccakUtf8(localTransactionDomain(chainId));
}

export function buildUnsignedLocalTransactionEnvelope({
  document,
  chainId,
  nonce,
  signerId,
  signerKeyId,
  signerRole,
  publicKey,
  issuedAtUnixMs
}) {
  const descriptor = localAlphaObjectDescriptor(document?.schema);
  if (!descriptor) {
    throw new Error(`unknown local transaction object schema: ${document?.schema}`);
  }
  const signerRoleCode = LOCAL_ALPHA_SIGNER_ROLES[signerRole];
  if (signerRoleCode === undefined) {
    throw new Error(`unknown local transaction signer role: ${signerRole}`);
  }

  const objectId = localAlphaObjectId(document);
  const objectTypeHash = localAlphaObjectTypeHash(document.schema);
  const domain = localTransactionDomain(chainId);
  const envelopeInput = {
    chainId,
    domainSeparator: localTransactionDomainSeparator(chainId),
    signerId,
    signerKeyId,
    signerRole: signerRoleCode,
    nonce,
    payloadHash: canonicalJsonHash(document),
    objectId,
    objectTypeHash,
    issuedAtUnixMs
  };
  const payload = localTransactionEnvelopePayload(envelopeInput);

  return {
    schema: "flowchain.local_transaction_envelope.v0",
    envelopeId: payload.structHash,
    domain,
    domainSeparator: envelopeInput.domainSeparator,
    chainId,
    nonce,
    signerId,
    signerKeyId,
    signerRole,
    signerRoleCode,
    publicKey,
    objectSchema: document.schema,
    objectType: descriptor.objectType,
    objectTypeHash,
    objectId,
    payloadHash: envelopeInput.payloadHash,
    issuedAtUnixMs,
    signingDigest: payload.signingDigest
  };
}

export function validateLocalTransactionEnvelope({
  document,
  envelope,
  context = {}
}) {
  const errors = [];
  const descriptor = localAlphaObjectDescriptor(document?.schema);
  if (!descriptor) {
    return { valid: false, errors: ["wrong-object-type"] };
  }
  if (!envelope || typeof envelope !== "object") {
    return { valid: false, errors: ["missing-signer"] };
  }

  const expectedDomain = localTransactionDomain(envelope.chainId);
  const expectedDomainSeparator = localTransactionDomainSeparator(envelope.chainId);
  const expectedRoleCode = LOCAL_ALPHA_SIGNER_ROLES[envelope.signerRole];

  if (context.chainId !== undefined && String(envelope.chainId) !== String(context.chainId)) {
    errors.push("wrong-chain-id");
  }
  if (envelope.domain !== expectedDomain || envelope.domainSeparator !== expectedDomainSeparator) {
    errors.push("wrong-domain");
  }
  if (
    envelope.objectSchema !== document.schema ||
    envelope.objectType !== descriptor.objectType ||
    envelope.objectTypeHash !== localAlphaObjectTypeHash(document.schema)
  ) {
    errors.push("wrong-object-type");
  }
  if (!descriptor.signerRoles.includes(envelope.signerRole)) {
    errors.push("wrong-signer");
  }
  if (
    !envelope.signerId ||
    !envelope.signerKeyId ||
    !envelope.publicKey ||
    !envelope.signature ||
    envelope.signerId === ZERO_BYTES32 ||
    envelope.signerKeyId === ZERO_BYTES32 ||
    expectedRoleCode === undefined ||
    envelope.signerRoleCode !== expectedRoleCode
  ) {
    errors.push("missing-signer");
  }
  if (context.expectedSignerId && envelope.signerId !== context.expectedSignerId) {
    errors.push("wrong-signer");
  }
  if (context.seenNonces?.has?.(localTransactionReplayKey(envelope))) {
    errors.push("replay");
  }

  try {
    const expectedObjectId = localAlphaObjectId(document);
    const expectedPayloadHash = canonicalJsonHash(document);
    if (envelope.objectId !== expectedObjectId) {
      errors.push("bad-object-id");
    }
    if (envelope.payloadHash !== expectedPayloadHash) {
      errors.push("bad-payload-hash");
    }

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
      envelope.publicKey &&
      !verifyDigest({
        digest: envelope.signingDigest,
        signature: envelope.signature,
        publicKey: envelope.publicKey
      })
    ) {
      errors.push("bad-signature");
    }
  } catch (error) {
    errors.push(/hex|bytes/i.test(String(error?.message)) ? "malformed-id" : "invalid-transaction");
  }

  return {
    valid: errors.length === 0,
    errors: [...new Set(errors)]
  };
}
