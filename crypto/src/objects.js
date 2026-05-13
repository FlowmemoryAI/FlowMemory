import {
  DOMAIN_STRINGS,
  LOCAL_ALPHA_FINALITY_STATES,
  LOCAL_ALPHA_SIGNER_ROLES,
  TYPE_STRINGS,
  ZERO_BYTES32
} from "./constants.js";
import { hexToBytes } from "./encoding.js";
import { verifyDigest } from "./attestations.js";
import { eip712Digest, verifierReportHash } from "./flowpulse.js";
import { domainSeparator, keccakUtf8, typedHash } from "./hashes.js";
import { workReceiptId } from "./domains.js";

export function agentAccountId({
  namespaceId,
  owner,
  policyRoot,
  toolPermissionsRoot,
  modelAllowlistRoot,
  memoryNamespaceRoot,
  spendingLimitPerEpoch,
  nonce
}) {
  return typedHash(TYPE_STRINGS.agentAccountV0, [
    ["bytes32", namespaceId],
    ["address", owner],
    ["bytes32", policyRoot],
    ["bytes32", toolPermissionsRoot],
    ["bytes32", modelAllowlistRoot],
    ["bytes32", memoryNamespaceRoot],
    ["uint256", spendingLimitPerEpoch],
    ["bytes32", nonce]
  ]);
}

export function modelPassportId({
  providerHash,
  modelFamilyHash,
  versionHash,
  licenseRoot,
  policyRoot,
  artifactRoot,
  metadataHash,
  nonce
}) {
  return typedHash(TYPE_STRINGS.modelPassportV0, [
    ["bytes32", providerHash],
    ["bytes32", modelFamilyHash],
    ["bytes32", versionHash],
    ["bytes32", licenseRoot],
    ["bytes32", policyRoot],
    ["bytes32", artifactRoot],
    ["bytes32", metadataHash],
    ["bytes32", nonce]
  ]);
}

export function memoryCellId({
  ownerAgentId,
  currentMemoryRoot,
  previousMemoryRoot,
  lastDeltaRoot,
  sourceReceiptsRoot,
  dependencyRoot,
  updatedAtUnixMs,
  cellVersion
}) {
  return typedHash(TYPE_STRINGS.memoryCellV0, [
    ["bytes32", ownerAgentId],
    ["bytes32", currentMemoryRoot],
    ["bytes32", previousMemoryRoot],
    ["bytes32", lastDeltaRoot],
    ["bytes32", sourceReceiptsRoot],
    ["bytes32", dependencyRoot],
    ["uint64", updatedAtUnixMs],
    ["uint16", cellVersion]
  ]);
}

export function artifactAvailabilityProofId({
  artifactRoot,
  providerId,
  locationCommitment,
  storageReceiptCommitment,
  availabilitySampleRoot,
  issuedAtUnixMs,
  expiresAtUnixMs,
  status,
  nonce
}) {
  return typedHash(TYPE_STRINGS.artifactAvailabilityProofV0, [
    ["bytes32", artifactRoot],
    ["bytes32", providerId],
    ["bytes32", locationCommitment],
    ["bytes32", storageReceiptCommitment],
    ["bytes32", availabilitySampleRoot],
    ["uint64", issuedAtUnixMs],
    ["uint64", expiresAtUnixMs],
    ["uint8", status],
    ["bytes32", nonce]
  ]);
}

export function verifierModuleId({
  ownerId,
  codeRoot,
  manifestRoot,
  supportedModesRoot,
  supportedChallengeTypesRoot,
  verifierSetRoot,
  moduleVersion,
  status
}) {
  return typedHash(TYPE_STRINGS.verifierModuleV0, [
    ["bytes32", ownerId],
    ["bytes32", codeRoot],
    ["bytes32", manifestRoot],
    ["bytes32", supportedModesRoot],
    ["bytes32", supportedChallengeTypesRoot],
    ["bytes32", verifierSetRoot],
    ["uint16", moduleVersion],
    ["uint8", status]
  ]);
}

export function challengeId({
  receiptId,
  challengerId,
  challengeType,
  evidenceRoot,
  openedAtUnixMs,
  deadlineUnixMs,
  status,
  nonce
}) {
  return typedHash(TYPE_STRINGS.challengeV0, [
    ["bytes32", receiptId],
    ["bytes32", challengerId],
    ["uint8", challengeType],
    ["bytes32", evidenceRoot],
    ["uint64", openedAtUnixMs],
    ["uint64", deadlineUnixMs],
    ["uint8", status],
    ["bytes32", nonce]
  ]);
}

export function finalityReceiptId({
  receiptId,
  reportId,
  challengeRoot,
  finalityState,
  finalizedAtUnixMs,
  finalizedBlockNumber,
  finalizedBlockHash,
  policyHash
}) {
  return typedHash(TYPE_STRINGS.finalityReceiptV0, [
    ["bytes32", receiptId],
    ["bytes32", reportId],
    ["bytes32", challengeRoot],
    ["uint8", finalityState],
    ["uint64", finalizedAtUnixMs],
    ["uint64", finalizedBlockNumber],
    ["bytes32", finalizedBlockHash],
    ["bytes32", policyHash]
  ]);
}

export function hardwareSignalEnvelopeId({
  deviceId,
  signalRoot,
  previousSignalEnvelopeId,
  channelRoot,
  sequence,
  observedAtUnixMs,
  transport,
  nonce
}) {
  return typedHash(TYPE_STRINGS.hardwareSignalEnvelopeV0, [
    ["bytes32", deviceId],
    ["bytes32", signalRoot],
    ["bytes32", previousSignalEnvelopeId],
    ["bytes32", channelRoot],
    ["uint64", sequence],
    ["uint64", observedAtUnixMs],
    ["uint8", transport],
    ["bytes32", nonce]
  ]);
}

export function controlPlaneProvenanceResponseId({
  requestId,
  subjectId,
  agentId,
  receiptId,
  reportId,
  memoryCellId,
  dependencyRoot,
  responseBodyHash,
  issuedAtUnixMs,
  responseVersion
}) {
  return typedHash(TYPE_STRINGS.controlPlaneProvenanceResponseV0, [
    ["bytes32", requestId],
    ["bytes32", subjectId],
    ["bytes32", agentId],
    ["bytes32", receiptId],
    ["bytes32", reportId],
    ["bytes32", memoryCellId],
    ["bytes32", dependencyRoot],
    ["bytes32", responseBodyHash],
    ["uint64", issuedAtUnixMs],
    ["uint16", responseVersion]
  ]);
}

export function bridgeDepositId({
  sourceChainId,
  sourceContract,
  txHash,
  logIndex,
  token,
  amount,
  sender,
  flowchainRecipient,
  nonce,
  metadataHash = ZERO_BYTES32
}) {
  return typedHash(TYPE_STRINGS.bridgeDepositV0, [
    ["uint256", sourceChainId],
    ["address", sourceContract],
    ["bytes32", txHash],
    ["uint32", logIndex],
    ["address", token],
    ["uint256", amount],
    ["address", sender],
    ["bytes32", flowchainRecipient],
    ["uint256", nonce],
    ["bytes32", metadataHash]
  ]);
}

export function bridgeCreditId({
  depositId,
  accountId,
  assetId,
  amount,
  creditedAtBlock,
  creditNonce,
  status
}) {
  return typedHash(TYPE_STRINGS.bridgeCreditV0, [
    ["bytes32", depositId],
    ["bytes32", accountId],
    ["bytes32", assetId],
    ["uint256", amount],
    ["uint64", creditedAtBlock],
    ["bytes32", creditNonce],
    ["uint8", status]
  ]);
}

export function bridgeWithdrawalId({
  accountId,
  destinationChainId,
  destinationAddress,
  token,
  amount,
  requestedNonce,
  feeCommitment,
  status
}) {
  return typedHash(TYPE_STRINGS.bridgeWithdrawalV0, [
    ["bytes32", accountId],
    ["uint256", destinationChainId],
    ["address", destinationAddress],
    ["address", token],
    ["uint256", amount],
    ["bytes32", requestedNonce],
    ["bytes32", feeCommitment],
    ["uint8", status]
  ]);
}

export function localAccountBalanceId({ chainId, accountId, assetId, available, locked, stateNonce, balanceRoot }) {
  return typedHash(TYPE_STRINGS.localAccountBalanceV0, [
    ["uint256", chainId],
    ["bytes32", accountId],
    ["bytes32", assetId],
    ["uint256", available],
    ["uint256", locked],
    ["uint64", stateNonce],
    ["bytes32", balanceRoot]
  ]);
}

export function localPublicKeyHash(publicKey) {
  return keccakUtf8(String(publicKey).toLowerCase());
}

export function localSignerId({ publicKey }) {
  return typedHash(TYPE_STRINGS.localSignerV0, [["bytes32", localPublicKeyHash(publicKey)]]);
}

export function localSignerKeyId({ publicKey, signerRole, keyScopeHash = domainSeparator("localTransactionEnvelope") }) {
  return typedHash(TYPE_STRINGS.localSignerKeyV0, [
    ["bytes32", localPublicKeyHash(publicKey)],
    ["uint8", signerRole],
    ["bytes32", keyScopeHash]
  ]);
}

export function localSignatureEnvelopeHash({
  objectId,
  objectTypeHash,
  domainSeparator,
  signerId,
  signerKeyId,
  signerRole,
  sequence,
  issuedAtUnixMs,
  expiresAtUnixMs,
  nonce
}) {
  return typedHash(TYPE_STRINGS.localSignatureEnvelopeV0, [
    ["bytes32", objectId],
    ["bytes32", objectTypeHash],
    ["bytes32", domainSeparator],
    ["bytes32", signerId],
    ["bytes32", signerKeyId],
    ["uint8", signerRole],
    ["uint64", sequence],
    ["uint64", issuedAtUnixMs],
    ["uint64", expiresAtUnixMs],
    ["bytes32", nonce]
  ]);
}

export const localSignatureEnvelopeId = localSignatureEnvelopeHash;

export function localSignatureEnvelopePayload(input) {
  const structHash = localSignatureEnvelopeHash(input);
  return {
    structHash,
    signingDigest: eip712Digest(input.domainSeparator, structHash)
  };
}

export function localAlphaObjectTypeHash(objectSchema) {
  return keccakUtf8(objectSchema);
}

export const LOCAL_ALPHA_OBJECT_DESCRIPTORS = Object.freeze({
  "flowchain.agent_account.v0": {
    objectType: "agent_account",
    idField: "agentId",
    domainName: "agentAccountId",
    signerRoles: ["operator"],
    nonzeroFields: [
      "agentId",
      "namespaceId",
      "policyRoot",
      "toolPermissionsRoot",
      "modelAllowlistRoot",
      "memoryNamespaceRoot",
      "nonce"
    ],
    hex32Fields: [
      "agentId",
      "namespaceId",
      "policyRoot",
      "toolPermissionsRoot",
      "modelAllowlistRoot",
      "memoryNamespaceRoot",
      "nonce"
    ],
    input: (document) => ({
      namespaceId: document.namespaceId,
      owner: document.owner,
      policyRoot: document.policyRoot,
      toolPermissionsRoot: document.toolPermissionsRoot,
      modelAllowlistRoot: document.modelAllowlistRoot,
      memoryNamespaceRoot: document.memoryNamespaceRoot,
      spendingLimitPerEpoch: document.spendingLimitPerEpoch,
      nonce: document.nonce
    }),
    id: agentAccountId
  },
  "flowchain.model_passport.v0": {
    objectType: "model_passport",
    idField: "modelId",
    domainName: "modelPassportId",
    signerRoles: ["operator"],
    nonzeroFields: [
      "modelId",
      "providerHash",
      "modelFamilyHash",
      "versionHash",
      "licenseRoot",
      "policyRoot",
      "artifactRoot",
      "metadataHash",
      "nonce"
    ],
    input: (document) => ({
      providerHash: document.providerHash,
      modelFamilyHash: document.modelFamilyHash,
      versionHash: document.versionHash,
      licenseRoot: document.licenseRoot,
      policyRoot: document.policyRoot,
      artifactRoot: document.artifactRoot,
      metadataHash: document.metadataHash,
      nonce: document.nonce
    }),
    id: modelPassportId
  },
  "flowchain.work_receipt.v0": {
    objectType: "work_receipt",
    idField: "workReceiptId",
    domainName: "workReceiptId",
    signerRoles: ["agent"],
    nonzeroFields: ["workReceiptId", "observationId", "receiptHash", "workerId", "nonce"],
    input: (document) => ({
      observationId: document.observationId,
      receiptHash: document.receiptHash,
      workerId: document.workerId,
      workerSequence: document.workerSequence,
      nonce: document.nonce
    }),
    id: workReceiptId
  },
  "flowchain.artifact_availability_proof.v0": {
    objectType: "artifact_availability_proof",
    idField: "proofId",
    domainName: "artifactAvailabilityProofId",
    signerRoles: ["operator"],
    nonzeroFields: [
      "proofId",
      "artifactRoot",
      "providerId",
      "locationCommitment",
      "storageReceiptCommitment",
      "availabilitySampleRoot",
      "nonce"
    ],
    input: (document) => ({
      artifactRoot: document.artifactRoot,
      providerId: document.providerId,
      locationCommitment: document.locationCommitment,
      storageReceiptCommitment: document.storageReceiptCommitment,
      availabilitySampleRoot: document.availabilitySampleRoot,
      issuedAtUnixMs: document.issuedAtUnixMs,
      expiresAtUnixMs: document.expiresAtUnixMs,
      status: document.statusCode,
      nonce: document.nonce
    }),
    id: artifactAvailabilityProofId
  },
  "flowchain.verifier_module.v0": {
    objectType: "verifier_module",
    idField: "moduleId",
    domainName: "verifierModuleId",
    signerRoles: ["verifier", "operator"],
    nonzeroFields: [
      "moduleId",
      "ownerId",
      "codeRoot",
      "manifestRoot",
      "supportedModesRoot",
      "supportedChallengeTypesRoot",
      "verifierSetRoot"
    ],
    input: (document) => ({
      ownerId: document.ownerId,
      codeRoot: document.codeRoot,
      manifestRoot: document.manifestRoot,
      supportedModesRoot: document.supportedModesRoot,
      supportedChallengeTypesRoot: document.supportedChallengeTypesRoot,
      verifierSetRoot: document.verifierSetRoot,
      moduleVersion: document.moduleVersion,
      status: document.statusCode
    }),
    id: verifierModuleId
  },
  "flowchain.verifier_report.v0": {
    objectType: "verifier_report",
    idField: "reportId",
    domainName: "verifierReportDigest",
    signerRoles: ["verifier"],
    nonzeroFields: [
      "reportId",
      "reportSchemaHash",
      "observationId",
      "receiptHash",
      "verifierId",
      "verifierSetRoot",
      "checksRoot",
      "finalizedBlockHash"
    ],
    input: (document) => ({
      reportSchemaHash: document.reportSchemaHash,
      observationId: document.observationId,
      receiptHash: document.receiptHash,
      verifierId: document.verifierId,
      verifierSetRoot: document.verifierSetRoot,
      status: document.statusCode,
      checksRoot: document.checksRoot,
      finalizedBlockNumber: document.finalizedBlockNumber,
      finalizedBlockHash: document.finalizedBlockHash,
      reportVersion: document.reportVersion
    }),
    id: verifierReportHash
  },
  "flowchain.memory_cell.v0": {
    objectType: "memory_cell",
    idField: "memoryCellId",
    domainName: "memoryCellId",
    signerRoles: ["agent"],
    dependencyField: "dependencyRoot",
    nonzeroFields: [
      "memoryCellId",
      "ownerAgentId",
      "currentMemoryRoot",
      "lastDeltaRoot",
      "sourceReceiptsRoot",
      "dependencyRoot"
    ],
    input: (document) => ({
      ownerAgentId: document.ownerAgentId,
      currentMemoryRoot: document.currentMemoryRoot,
      previousMemoryRoot: document.previousMemoryRoot,
      lastDeltaRoot: document.lastDeltaRoot,
      sourceReceiptsRoot: document.sourceReceiptsRoot,
      dependencyRoot: document.dependencyRoot,
      updatedAtUnixMs: document.updatedAtUnixMs,
      cellVersion: document.cellVersion
    }),
    id: memoryCellId,
    parentRootCheck(document) {
      return document.currentMemoryRoot !== ZERO_BYTES32 && document.currentMemoryRoot !== document.previousMemoryRoot;
    }
  },
  "flowchain.challenge.v0": {
    objectType: "challenge",
    idField: "challengeId",
    domainName: "challengeId",
    signerRoles: ["agent", "operator"],
    nonzeroFields: ["challengeId", "receiptId", "challengerId", "evidenceRoot", "nonce"],
    input: (document) => ({
      receiptId: document.receiptId,
      challengerId: document.challengerId,
      challengeType: document.challengeTypeCode,
      evidenceRoot: document.evidenceRoot,
      openedAtUnixMs: document.openedAtUnixMs,
      deadlineUnixMs: document.deadlineUnixMs,
      status: document.statusCode,
      nonce: document.nonce
    }),
    id: challengeId
  },
  "flowchain.finality_receipt.v0": {
    objectType: "finality_receipt",
    idField: "finalityReceiptId",
    domainName: "finalityReceiptId",
    signerRoles: ["verifier"],
    nonzeroFields: ["finalityReceiptId", "receiptId", "reportId", "challengeRoot", "policyHash"],
    input: (document) => ({
      receiptId: document.receiptId,
      reportId: document.reportId,
      challengeRoot: document.challengeRoot,
      finalityState: document.finalityStateCode,
      finalizedAtUnixMs: document.finalizedAtUnixMs,
      finalizedBlockNumber: document.finalizedBlockNumber,
      finalizedBlockHash: document.finalizedBlockHash,
      policyHash: document.policyHash
    }),
    id: finalityReceiptId,
    parentRootCheck(document) {
      if (document.finalityStateCode !== LOCAL_ALPHA_FINALITY_STATES.finalized) {
        return true;
      }
      return (
        document.finalizedAtUnixMs !== "0" &&
        document.finalizedBlockNumber !== "0" &&
        document.finalizedBlockHash !== ZERO_BYTES32
      );
    }
  },
  "flowmemory.bridge_deposit.v0": {
    objectType: "bridge_deposit",
    idField: "depositId",
    domainName: "bridgeDepositId",
    signerRoles: ["operator"],
    nonzeroFields: ["depositId", "txHash", "flowchainRecipient"],
    hex32Fields: ["depositId", "txHash", "flowchainRecipient", "metadataHash"],
    addressFields: ["sourceContract", "token", "sender"],
    positiveUintFields: ["amount"],
    input: (document) => ({
      sourceChainId: document.sourceChainId,
      sourceContract: document.sourceContract,
      txHash: document.txHash,
      logIndex: document.logIndex,
      token: document.token,
      amount: document.amount,
      sender: document.sender,
      flowchainRecipient: document.flowchainRecipient,
      nonce: document.nonce,
      metadataHash: document.metadataHash ?? ZERO_BYTES32
    }),
    id: bridgeDepositId
  },
  "flowchain.bridge_credit.v0": {
    objectType: "bridge_credit",
    idField: "creditId",
    domainName: "bridgeCreditId",
    signerRoles: ["operator"],
    nonzeroFields: ["creditId", "depositId", "accountId", "assetId", "creditNonce"],
    hex32Fields: ["creditId", "depositId", "accountId", "assetId", "creditNonce"],
    positiveUintFields: ["amount"],
    input: (document) => ({
      depositId: document.depositId,
      accountId: document.accountId,
      assetId: document.assetId,
      amount: document.amount,
      creditedAtBlock: document.creditedAtBlock,
      creditNonce: document.creditNonce,
      status: document.statusCode
    }),
    id: bridgeCreditId
  },
  "flowchain.bridge_withdrawal.v0": {
    objectType: "bridge_withdrawal",
    idField: "withdrawalId",
    domainName: "bridgeWithdrawalId",
    signerRoles: ["operator"],
    nonzeroFields: ["withdrawalId", "accountId", "requestedNonce", "feeCommitment"],
    hex32Fields: ["withdrawalId", "accountId", "requestedNonce", "feeCommitment"],
    addressFields: ["destinationAddress", "token"],
    positiveUintFields: ["amount"],
    input: (document) => ({
      accountId: document.accountId,
      destinationChainId: document.destinationChainId,
      destinationAddress: document.destinationAddress,
      token: document.token,
      amount: document.amount,
      requestedNonce: document.requestedNonce,
      feeCommitment: document.feeCommitment,
      status: document.statusCode
    }),
    id: bridgeWithdrawalId
  },
  "flowchain.local_account_balance.v0": {
    objectType: "local_account_balance",
    idField: "balanceId",
    domainName: "localAccountBalanceId",
    signerRoles: ["operator"],
    nonzeroFields: ["balanceId", "accountId", "assetId", "balanceRoot"],
    hex32Fields: ["balanceId", "accountId", "assetId", "balanceRoot"],
    input: (document) => ({
      chainId: document.chainId,
      accountId: document.accountId,
      assetId: document.assetId,
      available: document.available,
      locked: document.locked,
      stateNonce: document.stateNonce,
      balanceRoot: document.balanceRoot
    }),
    id: localAccountBalanceId
  },
  "flowchain.hardware_signal_envelope.v0": {
    objectType: "hardware_signal_envelope",
    idField: "hardwareSignalEnvelopeId",
    domainName: "hardwareSignalEnvelopeId",
    signerRoles: ["hardware"],
    nonzeroFields: ["hardwareSignalEnvelopeId", "deviceId", "signalRoot", "channelRoot", "nonce"],
    input: (document) => ({
      deviceId: document.deviceId,
      signalRoot: document.signalRoot,
      previousSignalEnvelopeId: document.previousSignalEnvelopeId,
      channelRoot: document.channelRoot,
      sequence: document.sequence,
      observedAtUnixMs: document.observedAtUnixMs,
      transport: document.transportCode,
      nonce: document.nonce
    }),
    id: hardwareSignalEnvelopeId,
    parentRootCheck(document) {
      return document.previousSignalEnvelopeId !== document.hardwareSignalEnvelopeId;
    }
  },
  "flowchain.control_plane_provenance_response.v0": {
    objectType: "control_plane_provenance_response",
    idField: "provenanceResponseId",
    domainName: "controlPlaneProvenanceResponseId",
    signerRoles: ["operator", "agent"],
    dependencyField: "dependencyRoot",
    nonzeroFields: [
      "provenanceResponseId",
      "requestId",
      "subjectId",
      "agentId",
      "receiptId",
      "reportId",
      "memoryCellId",
      "dependencyRoot",
      "responseBodyHash"
    ],
    input: (document) => ({
      requestId: document.requestId,
      subjectId: document.subjectId,
      agentId: document.agentId,
      receiptId: document.receiptId,
      reportId: document.reportId,
      memoryCellId: document.memoryCellId,
      dependencyRoot: document.dependencyRoot,
      responseBodyHash: document.responseBodyHash,
      issuedAtUnixMs: document.issuedAtUnixMs,
      responseVersion: document.responseVersion
    }),
    id: controlPlaneProvenanceResponseId
  }
});

export function localAlphaObjectDescriptor(objectSchema) {
  return LOCAL_ALPHA_OBJECT_DESCRIPTORS[objectSchema];
}

export function localAlphaObjectInput(document) {
  const descriptor = localAlphaObjectDescriptor(document?.schema);
  if (!descriptor) {
    throw new Error(`unknown local alpha object schema: ${document?.schema}`);
  }
  return descriptor.input(document);
}

export function localAlphaObjectId(document) {
  const descriptor = localAlphaObjectDescriptor(document?.schema);
  if (!descriptor) {
    throw new Error(`unknown local alpha object schema: ${document?.schema}`);
  }
  return descriptor.id(descriptor.input(document));
}

export function validateLocalAlphaObjectDocument(document, context = {}) {
  const errors = [];
  const descriptor = localAlphaObjectDescriptor(document?.schema);

  if (!descriptor) {
    return { valid: false, errors: ["wrong-object-type"] };
  }

  if (context.expectedObjectType && descriptor.objectType !== context.expectedObjectType) {
    errors.push("changed-object-type");
  }

  const idField = descriptor.idField;
  if (!isHex32(document[idField])) {
    errors.push("malformed-id");
  }

  for (const field of descriptor.hex32Fields ?? []) {
    if (document[field] !== undefined && !isHex32(document[field])) {
      errors.push(field.toLowerCase().includes("root") ? "malformed-root" : "malformed-id");
      break;
    }
  }

  for (const field of descriptor.addressFields ?? []) {
    if (!isAddress(document[field])) {
      errors.push("malformed-address");
      break;
    }
  }

  for (const field of descriptor.positiveUintFields ?? []) {
    if (!isPositiveUint(document[field])) {
      errors.push(descriptor.objectType === "bridge_deposit" ? "malformed-bridge-deposit" : "malformed-uint");
      break;
    }
  }

  for (const field of descriptor.nonzeroFields ?? []) {
    if (document[field] === ZERO_BYTES32) {
      errors.push(field.toLowerCase().includes("root") ? "malformed-root" : "zero-hash");
      break;
    }
  }

  if (descriptor.dependencyField) {
    const dependency = document[descriptor.dependencyField];
    if (!isHex32(dependency) || dependency === ZERO_BYTES32) {
      errors.push("malformed-dependency");
    }
  }

  if (descriptor.parentRootCheck && !descriptor.parentRootCheck(document)) {
    errors.push("bad-parent-root");
  }

  try {
    const expectedObjectId = localAlphaObjectId(document);
    if (document[idField] !== expectedObjectId) {
      errors.push("bad-object-id");
    }
  } catch (error) {
    errors.push(classifyObjectError(error));
  }

  return {
    valid: errors.length === 0,
    errors: [...new Set(errors)]
  };
}

export function localAlphaEnvelopeReplayKey(envelope) {
  return `${envelope.signerId}:${envelope.domain}:${envelope.sequence}`;
}

export function localSignatureEnvelopeInput(envelope) {
  return {
    objectId: envelope.objectId,
    objectTypeHash: envelope.objectTypeHash,
    domainSeparator: envelope.domainSeparator,
    signerId: envelope.signerId,
    signerKeyId: envelope.signerKeyId,
    signerRole: envelope.signerRoleCode,
    sequence: envelope.sequence,
    issuedAtUnixMs: envelope.issuedAtUnixMs,
    expiresAtUnixMs: envelope.expiresAtUnixMs,
    nonce: envelope.nonce
  };
}

export function validateLocalAlphaEnvelope({ document, envelope, context = {} }) {
  const errors = [];
  const descriptor = localAlphaObjectDescriptor(document?.schema);

  if (!descriptor) {
    errors.push("wrong-object-type");
    return { valid: false, errors };
  }

  errors.push(...validateLocalAlphaObjectDocument(document).errors);

  if (!envelope || typeof envelope !== "object") {
    errors.push("missing-signer");
    return { valid: false, errors };
  }

  const expectedObjectTypeHash = localAlphaObjectTypeHash(document.schema);
  const expectedDomain = DOMAIN_STRINGS[descriptor.domainName];
  const expectedDomainSeparator = domainSeparator(descriptor.domainName);

  if (envelope.objectSchema !== document.schema || envelope.objectType !== descriptor.objectType) {
    errors.push("wrong-object-type");
  }
  if (envelope.objectTypeHash !== expectedObjectTypeHash) {
    errors.push("wrong-object-type");
  }
  if (envelope.domain !== expectedDomain || envelope.domainSeparator !== expectedDomainSeparator) {
    errors.push("wrong-domain");
  }

  const idField = descriptor.idField;
  if (!isHex32(document[idField]) || !isHex32(envelope.objectId) || !isHex32(envelope.envelopeId)) {
    errors.push("malformed-id");
  }

  for (const field of descriptor.nonzeroFields ?? []) {
    if (document[field] === ZERO_BYTES32 || envelope.objectId === ZERO_BYTES32) {
      errors.push("zero-hash");
      break;
    }
  }

  if (descriptor.dependencyField) {
    const dependency = document[descriptor.dependencyField];
    if (!isHex32(dependency) || dependency === ZERO_BYTES32) {
      errors.push("malformed-dependency");
    }
  }

  if (descriptor.parentRootCheck && !descriptor.parentRootCheck(document)) {
    errors.push("bad-parent-root");
  }

  try {
    const expectedObjectId = localAlphaObjectId(document);
    if (document[idField] !== expectedObjectId || envelope.objectId !== expectedObjectId) {
      errors.push("bad-object-id");
    }
  } catch (error) {
    errors.push(classifyObjectError(error));
  }

  const signerRoleCode = LOCAL_ALPHA_SIGNER_ROLES[envelope.signerRole];
  const signerMissing =
    !envelope.signerId ||
    !envelope.signerKeyId ||
    !envelope.publicKey ||
    !envelope.signature ||
    envelope.signerId === ZERO_BYTES32 ||
    envelope.signerKeyId === ZERO_BYTES32 ||
    signerRoleCode === undefined ||
    signerRoleCode !== envelope.signerRoleCode ||
    !descriptor.signerRoles.includes(envelope.signerRole);

  if (signerMissing) {
    errors.push("missing-signer");
  }

  const seenSequences = context.seenSequences;
  if (seenSequences?.has?.(localAlphaEnvelopeReplayKey(envelope))) {
    errors.push("replay");
  }

  try {
    const envelopeInput = localSignatureEnvelopeInput(envelope);
    const expectedEnvelopeId = localSignatureEnvelopeHash(envelopeInput);
    const expectedPayload = localSignatureEnvelopePayload(envelopeInput);
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
    errors.push(classifyObjectError(error));
  }

  return {
    valid: errors.length === 0,
    errors: [...new Set(errors)]
  };
}

function isHex32(value) {
  if (typeof value !== "string") {
    return false;
  }
  try {
    hexToBytes(value, 32);
    return true;
  } catch {
    return false;
  }
}

function isAddress(value) {
  if (typeof value !== "string") {
    return false;
  }
  try {
    hexToBytes(value, 20);
    return true;
  } catch {
    return false;
  }
}

function isPositiveUint(value) {
  if (typeof value !== "string" && typeof value !== "number" && typeof value !== "bigint") {
    return false;
  }
  if (typeof value === "string" && !/^[0-9]+$/.test(value)) {
    return false;
  }
  try {
    return BigInt(value) > 0n;
  } catch {
    return false;
  }
}

function classifyObjectError(error) {
  if (/hex|bytes/i.test(String(error?.message))) {
    return "malformed-id";
  }
  return "invalid-object";
}
