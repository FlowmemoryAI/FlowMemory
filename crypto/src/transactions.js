import { DOMAIN_STRINGS, LOCAL_ALPHA_SIGNER_ROLES, TYPE_STRINGS, ZERO_BYTES32 } from "./constants.js";
import { verifyDigest } from "./attestations.js";
import { eip712Digest } from "./flowpulse.js";
import { canonicalJsonHash, domainSeparator, keccakUtf8, typedHash } from "./hashes.js";
import {
  FLOWMEMORY_NETWORK_PROFILES,
  flowmemoryNetworkProfileHash,
  flowmemoryProductionDomain,
  flowmemoryProductionDomainSeparator,
  flowmemoryTransactionId
} from "./production-network.js";
import {
  flowmemoryAccountId,
  flowmemoryAddressFromPublicKey,
  isFlowMemoryRole,
  normalizeFlowMemoryPublicKey
} from "./identity.js";
import {
  localAlphaObjectDescriptor,
  localAlphaObjectId,
  localAlphaObjectTypeHash
} from "./objects.js";

export function localTransactionEnvelopeHash(input) {
  if (isProductionNetworkEnvelopeInput(input)) {
    return typedHash(TYPE_STRINGS.localTransactionEnvelopeProductionNetworkV0, [
      ["uint16", input.schemaVersion],
      ["uint256", input.chainId],
      ["bytes32", input.networkProfileHash ?? flowmemoryNetworkProfileHash(input.networkProfile)],
      ["bytes32", input.domainSeparator],
      ["bytes32", input.signerId],
      ["bytes32", input.signerKeyId],
      ["uint8", input.signerRole],
      ["uint64", input.nonce],
      ["bytes32", input.payloadTypeHash ?? keccakUtf8(input.payloadType)],
      ["bytes32", input.payloadHash],
      ["bytes32", input.objectId],
      ["bytes32", input.objectTypeHash],
      ["uint64", input.issuedAtUnixMs],
      ["uint64", input.expiresAtUnixMs],
      ["bytes32", input.localExecutionCostHash ?? canonicalJsonHash(input.localExecutionCost ?? defaultLocalExecutionCost())],
      ["bytes32", input.feeHash ?? canonicalJsonHash(input.fee ?? defaultFee())],
      ["bytes32", input.signatureAlgorithmHash ?? keccakUtf8(input.signatureAlgorithm)]
    ]);
  }
  return typedHash(TYPE_STRINGS.localTransactionEnvelopeV0, [
    ["uint256", input.chainId],
    ["bytes32", input.domainSeparator],
    ["bytes32", input.signerId],
    ["bytes32", input.signerKeyId],
    ["uint8", input.signerRole],
    ["uint64", input.nonce],
    ["bytes32", input.payloadHash],
    ["bytes32", input.objectId],
    ["bytes32", input.objectTypeHash],
    ["uint64", input.issuedAtUnixMs]
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
  const input = {
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
  if (isProductionNetworkEnvelopeInput(envelope)) {
    return {
      schemaVersion: envelope.schemaVersion,
      chainId: envelope.chainId,
      networkProfile: envelope.networkProfile,
      networkProfileHash: envelope.networkProfileHash,
      domainSeparator: envelope.domainSeparator,
      signerId: envelope.signerId,
      signerKeyId: envelope.signerKeyId,
      signerRole: envelope.signerRoleCode,
      nonce: envelope.nonce,
      payloadType: envelope.payloadType,
      payloadTypeHash: envelope.payloadTypeHash,
      payloadHash: envelope.payloadHash,
      objectId: envelope.objectId,
      objectTypeHash: envelope.objectTypeHash,
      issuedAtUnixMs: envelope.issuedAtUnixMs,
      expiresAtUnixMs: envelope.expiresAtUnixMs,
      localExecutionCostHash: envelope.localExecutionCostHash,
      feeHash: envelope.feeHash,
      signatureAlgorithm: envelope.signatureAlgorithm,
      signatureAlgorithmHash: envelope.signatureAlgorithmHash
    };
  }
  return input;
}

export function localTransactionReplayKey(envelope) {
  if (envelope?.networkProfile) {
    return `${envelope.chainId}:${envelope.networkProfile}:${envelope.signerId}:${envelope.signerRole}:${envelope.nonce}`;
  }
  return `${envelope.chainId}:${envelope.domain}:${envelope.signerId}:${envelope.nonce}`;
}

export function localTransactionDomain(chainId, networkProfile) {
  if (networkProfile) {
    return flowmemoryProductionDomain({ chainId, networkProfile });
  }
  return `${DOMAIN_STRINGS.localTransactionEnvelope}:chain:${chainId}`;
}

export function localTransactionDomainSeparator(chainId, networkProfile) {
  if (networkProfile) {
    return flowmemoryProductionDomainSeparator({ chainId, networkProfile });
  }
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
  issuedAtUnixMs,
  expiresAtUnixMs,
  networkProfile = FLOWMEMORY_NETWORK_PROFILES.localChain,
  payloadType,
  localExecutionCost = defaultLocalExecutionCost(),
  fee = defaultFee(),
  signatureAlgorithm = "secp256k1-keccak256-eip712-local-v0",
  canonical = true
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
  const domain = localTransactionDomain(chainId, canonical ? networkProfile : undefined);
  const envelopeInput = {
    ...(canonical
      ? {
          schemaVersion: 1,
          networkProfile,
          networkProfileHash: flowmemoryNetworkProfileHash(networkProfile),
          payloadType: payloadType ?? descriptor.objectType,
          payloadTypeHash: keccakUtf8(payloadType ?? descriptor.objectType),
          expiresAtUnixMs: expiresAtUnixMs ?? defaultExpiresAtUnixMs(issuedAtUnixMs),
          localExecutionCostHash: canonicalJsonHash(localExecutionCost),
          feeHash: canonicalJsonHash(fee),
          signatureAlgorithm,
          signatureAlgorithmHash: keccakUtf8(signatureAlgorithm)
        }
      : {}),
    chainId,
    domainSeparator: localTransactionDomainSeparator(chainId, canonical ? networkProfile : undefined),
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
    schema: "flowmemory.local_transaction_envelope.v0",
    ...(canonical
      ? {
          schemaVersion: envelopeInput.schemaVersion,
          networkProfile,
          networkProfileHash: envelopeInput.networkProfileHash
        }
      : {}),
    envelopeId: payload.structHash,
    domain,
    domainSeparator: envelopeInput.domainSeparator,
    chainId,
    nonce,
    signerId,
    signerKeyId,
    signerRole,
    signerRoleCode,
    publicKey: canonical ? normalizeFlowMemoryPublicKey(publicKey) : publicKey,
    ...(canonical
      ? {
          publicKeyEncoding: "secp256k1-compressed-hex",
          signerAddress: flowmemoryAddressFromPublicKey(publicKey)
        }
      : {}),
    objectSchema: document.schema,
    objectType: descriptor.objectType,
    ...(canonical
      ? {
          payloadType: envelopeInput.payloadType,
          payloadTypeHash: envelopeInput.payloadTypeHash
        }
      : {}),
    objectTypeHash,
    objectId,
    payloadHash: envelopeInput.payloadHash,
    issuedAtUnixMs,
    ...(canonical
      ? {
          expiresAtUnixMs: envelopeInput.expiresAtUnixMs,
          localExecutionCost,
          localExecutionCostHash: envelopeInput.localExecutionCostHash,
          fee,
          feeHash: envelopeInput.feeHash,
          signatureAlgorithm,
          signatureAlgorithmHash: envelopeInput.signatureAlgorithmHash
        }
      : {}),
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

  const canonicalEnvelope = isProductionNetworkEnvelopeInput(envelope);
  const expectedDomain = localTransactionDomain(envelope.chainId, canonicalEnvelope ? envelope.networkProfile : undefined);
  const expectedDomainSeparator = localTransactionDomainSeparator(
    envelope.chainId,
    canonicalEnvelope ? envelope.networkProfile : undefined
  );
  const expectedRoleCode = LOCAL_ALPHA_SIGNER_ROLES[envelope.signerRole];

  if (context.chainId !== undefined && String(envelope.chainId) !== String(context.chainId)) {
    errors.push("wrong-chain-id");
  }
  if (context.networkProfile !== undefined && envelope.networkProfile !== context.networkProfile) {
    errors.push("wrong-network-profile");
  }
  if (context.expectedNonce !== undefined && String(envelope.nonce) !== String(context.expectedNonce)) {
    errors.push("wrong-nonce");
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
    errors.push("duplicate-nonce");
  }
  if (context.minimumNonce !== undefined && BigInt(envelope.nonce) < BigInt(context.minimumNonce)) {
    errors.push("stale-nonce");
  }
  if (context.expectedPayloadType !== undefined && envelope.payloadType !== context.expectedPayloadType) {
    errors.push("wrong-payload-type");
  }
  if (context.requireCanonical && !canonicalEnvelope) {
    errors.push("missing-canonical-field");
  }

  try {
    const expectedObjectId = localAlphaObjectId(document);
    const expectedPayloadHash = canonicalJsonHash(document);
    const idField = descriptor.idField;
    if (!isHex32(document[idField]) || !isHex32(envelope.objectId) || !isHex32(envelope.envelopeId)) {
      errors.push("malformed-id");
    }
    if (document[idField] !== expectedObjectId) {
      errors.push("bad-object-id");
    }
    for (const field of descriptor.nonzeroFields ?? []) {
      if (document[field] === ZERO_BYTES32 || envelope.objectId === ZERO_BYTES32) {
        errors.push("zero-hash");
        break;
      }
    }
    if (descriptor.parentRootCheck && !descriptor.parentRootCheck(document)) {
      errors.push("invalid-transaction");
    }
    if (envelope.objectId !== expectedObjectId) {
      errors.push("bad-object-id");
    }
    if (envelope.payloadHash !== expectedPayloadHash) {
      errors.push("bad-payload-hash");
    }
    if (canonicalEnvelope) {
      validateProductionNetworkEnvelopeExtension(envelope, errors, context);
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
    errors.push(classifyTransactionError(error));
  }

  return {
    valid: errors.length === 0,
    errors: [...new Set(errors)]
  };
}

function isHex32(value) {
  return typeof value === "string" && /^0x[0-9a-fA-F]{64}$/.test(value);
}

function isProductionNetworkEnvelopeInput(input) {
  return Boolean(input?.schemaVersion || input?.networkProfile || input?.payloadType || input?.expiresAtUnixMs);
}

function defaultLocalExecutionCost() {
  return {
    unit: "local-compute",
    amount: "0",
    metering: "not-metered-local-private-testnet"
  };
}

function defaultFee() {
  return {
    assetId: ZERO_BYTES32,
    amount: "0",
    policy: "no-value-local-private-testnet"
  };
}

function defaultExpiresAtUnixMs(issuedAtUnixMs) {
  return (BigInt(issuedAtUnixMs) + 3_600_000n).toString();
}

function validateProductionNetworkEnvelopeExtension(envelope, errors, context) {
  const required = [
    "schemaVersion",
    "networkProfile",
    "networkProfileHash",
    "payloadType",
    "payloadTypeHash",
    "expiresAtUnixMs",
    "localExecutionCost",
    "localExecutionCostHash",
    "fee",
    "feeHash",
    "signatureAlgorithm",
    "signatureAlgorithmHash"
  ];
  for (const field of required) {
    if (envelope[field] === undefined || envelope[field] === null || envelope[field] === "") {
      errors.push("missing-canonical-field");
    }
  }
  if (envelope.schemaVersion !== 1) {
    errors.push("wrong-schema-version");
  }
  if (envelope.networkProfileHash !== flowmemoryNetworkProfileHash(envelope.networkProfile)) {
    errors.push("wrong-network-profile");
  }
  if (envelope.payloadTypeHash !== keccakUtf8(envelope.payloadType)) {
    errors.push("wrong-payload-type");
  }
  if (envelope.localExecutionCostHash !== canonicalJsonHash(envelope.localExecutionCost)) {
    errors.push("bad-local-execution-cost");
  }
  if (envelope.feeHash !== canonicalJsonHash(envelope.fee)) {
    errors.push("bad-fee");
  }
  if (envelope.signatureAlgorithmHash !== keccakUtf8(envelope.signatureAlgorithm)) {
    errors.push("bad-signature-algorithm");
  }
  if (BigInt(envelope.expiresAtUnixMs) < BigInt(envelope.issuedAtUnixMs)) {
    errors.push("expired-tx");
  }
  if (context.nowUnixMs !== undefined && BigInt(envelope.expiresAtUnixMs) < BigInt(context.nowUnixMs)) {
    errors.push("expired-tx");
  }
  try {
    normalizeFlowMemoryPublicKey(envelope.publicKey);
  } catch {
    errors.push("malformed-public-key");
  }
  if (isFlowMemoryRole(envelope.signerRole)) {
    const derivedSignerId = flowmemoryAccountId({ publicKey: envelope.publicKey, role: envelope.signerRole });
    if (envelope.signerId !== derivedSignerId) {
      errors.push("wrong-signer");
    }
    if (envelope.signerAddress && envelope.signerAddress !== flowmemoryAddressFromPublicKey(envelope.publicKey)) {
      errors.push("wrong-signer");
    }
  }
  if (envelope.signature && !/^0x[0-9a-fA-F]{128}$/.test(envelope.signature)) {
    errors.push("malformed-signature");
  }
  if (envelope.signature) {
    const expectedTransactionId = flowmemoryTransactionId(envelope);
    if (envelope.transactionId && envelope.transactionId !== expectedTransactionId) {
      errors.push("bad-transaction-id");
    }
    if (context.seenTransactionIds?.has?.(envelope.transactionId ?? expectedTransactionId)) {
      errors.push("duplicate-tx-id");
    }
  }
}

function classifyTransactionError(error) {
  if (/public key/i.test(String(error?.message))) {
    return "malformed-public-key";
  }
  if (/signature/i.test(String(error?.message))) {
    return "malformed-signature";
  }
  if (/hex|bytes/i.test(String(error?.message))) {
    return "malformed-id";
  }
  return "invalid-transaction";
}
