import {
  DOMAIN_STRINGS,
  LOCAL_ALPHA_BRIDGE_STATUSES,
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
  metadataHash
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
  recipient,
  assetId,
  amount,
  creditedAtBlockNumber,
  creditedAtUnixMs,
  status,
  nonce
}) {
  return typedHash(TYPE_STRINGS.bridgeCreditV0, [
    ["bytes32", depositId],
    ["bytes32", recipient],
    ["bytes32", assetId],
    ["uint256", amount],
    ["uint64", creditedAtBlockNumber],
    ["uint64", creditedAtUnixMs],
    ["uint8", status],
    ["bytes32", nonce]
  ]);
}

export function bridgeWithdrawalId({
  accountId,
  destinationChainId,
  destinationContract,
  token,
  amount,
  recipient,
  requestedAtBlockNumber,
  requestedAtUnixMs,
  status,
  nonce,
  metadataHash
}) {
  return typedHash(TYPE_STRINGS.bridgeWithdrawalV0, [
    ["bytes32", accountId],
    ["uint256", destinationChainId],
    ["address", destinationContract],
    ["address", token],
    ["uint256", amount],
    ["address", recipient],
    ["uint64", requestedAtBlockNumber],
    ["uint64", requestedAtUnixMs],
    ["uint8", status],
    ["bytes32", nonce],
    ["bytes32", metadataHash]
  ]);
}

export function localBalanceRecordId({
  accountId,
  assetId,
  availableAmount,
  lockedAmount,
  lastCreditId,
  lastWithdrawalId,
  stateRoot,
  updatedAtBlockNumber,
  nonce
}) {
  return typedHash(TYPE_STRINGS.localBalanceRecordV0, [
    ["bytes32", accountId],
    ["bytes32", assetId],
    ["uint256", availableAmount],
    ["uint256", lockedAmount],
    ["bytes32", lastCreditId],
    ["bytes32", lastWithdrawalId],
    ["bytes32", stateRoot],
    ["uint64", updatedAtBlockNumber],
    ["bytes32", nonce]
  ]);
}

export function productTransferId({
  fromAccountId,
  toAccountId,
  assetId,
  amount,
  accountNonce,
  deadlineBlock,
  memoHash
}) {
  return typedHash(TYPE_STRINGS.productTransferV0, [
    ["bytes32", fromAccountId],
    ["bytes32", toAccountId],
    ["bytes32", assetId],
    ["uint256", amount],
    ["uint64", accountNonce],
    ["uint64", deadlineBlock],
    ["bytes32", memoHash]
  ]);
}

export function productTokenLaunchId({
  issuerAccountId,
  tokenId,
  symbolHash,
  nameHash,
  metadataHash,
  decimals,
  initialSupply,
  recipientAccountId,
  accountNonce,
  launchPolicyHash
}) {
  return typedHash(TYPE_STRINGS.productTokenLaunchV0, [
    ["bytes32", issuerAccountId],
    ["bytes32", tokenId],
    ["bytes32", symbolHash],
    ["bytes32", nameHash],
    ["bytes32", metadataHash],
    ["uint8", decimals],
    ["uint256", initialSupply],
    ["bytes32", recipientAccountId],
    ["uint64", accountNonce],
    ["bytes32", launchPolicyHash]
  ]);
}

export function productPoolCreateId({
  creatorAccountId,
  poolId,
  baseAssetId,
  quoteAssetId,
  feeBps,
  tickSpacing,
  metadataHash,
  accountNonce
}) {
  return typedHash(TYPE_STRINGS.productPoolCreateV0, [
    ["bytes32", creatorAccountId],
    ["bytes32", poolId],
    ["bytes32", baseAssetId],
    ["bytes32", quoteAssetId],
    ["uint32", feeBps],
    ["uint32", tickSpacing],
    ["bytes32", metadataHash],
    ["uint64", accountNonce]
  ]);
}

export function productAddLiquidityId({
  providerAccountId,
  poolId,
  baseAmount,
  quoteAmount,
  minLiquidityTokens,
  deadlineBlock,
  accountNonce
}) {
  return typedHash(TYPE_STRINGS.productAddLiquidityV0, [
    ["bytes32", providerAccountId],
    ["bytes32", poolId],
    ["uint256", baseAmount],
    ["uint256", quoteAmount],
    ["uint256", minLiquidityTokens],
    ["uint64", deadlineBlock],
    ["uint64", accountNonce]
  ]);
}

export function productRemoveLiquidityId({
  providerAccountId,
  poolId,
  liquidityTokens,
  minBaseAmount,
  minQuoteAmount,
  deadlineBlock,
  accountNonce
}) {
  return typedHash(TYPE_STRINGS.productRemoveLiquidityV0, [
    ["bytes32", providerAccountId],
    ["bytes32", poolId],
    ["uint256", liquidityTokens],
    ["uint256", minBaseAmount],
    ["uint256", minQuoteAmount],
    ["uint64", deadlineBlock],
    ["uint64", accountNonce]
  ]);
}

export function productSwapId({
  traderAccountId,
  poolId,
  assetInId,
  assetOutId,
  amountIn,
  minAmountOut,
  deadlineBlock,
  accountNonce
}) {
  return typedHash(TYPE_STRINGS.productSwapV0, [
    ["bytes32", traderAccountId],
    ["bytes32", poolId],
    ["bytes32", assetInId],
    ["bytes32", assetOutId],
    ["uint256", amountIn],
    ["uint256", minAmountOut],
    ["uint64", deadlineBlock],
    ["uint64", accountNonce]
  ]);
}

export function productBridgeCreditAckId({
  creditId,
  depositId,
  accountId,
  assetId,
  amount,
  acknowledgedAtBlockNumber,
  accountNonce
}) {
  return typedHash(TYPE_STRINGS.productBridgeCreditAckV0, [
    ["bytes32", creditId],
    ["bytes32", depositId],
    ["bytes32", accountId],
    ["bytes32", assetId],
    ["uint256", amount],
    ["uint64", acknowledgedAtBlockNumber],
    ["uint64", accountNonce]
  ]);
}

export function bridgeWithdrawalIntentId({
  creditId,
  depositId,
  sourceChainId,
  destinationChainId,
  token,
  amount,
  flowchainAccount,
  baseRecipient,
  status,
  requestedAt,
  testMode,
  broadcast,
  releasePolicy,
  productionReady
}) {
  return typedHash(TYPE_STRINGS.bridgeWithdrawalIntentV0, [
    ["bytes32", creditId],
    ["bytes32", depositId],
    ["uint256", sourceChainId],
    ["uint256", destinationChainId],
    ["address", token],
    ["uint256", amount],
    ["bytes32", flowchainAccount],
    ["address", baseRecipient],
    ["bytes32", keccakUtf8(status)],
    ["bytes32", keccakUtf8(requestedAt)],
    ["uint8", booleanCode(testMode)],
    ["uint8", booleanCode(broadcast)],
    ["bytes32", keccakUtf8(releasePolicy)],
    ["uint8", booleanCode(productionReady)]
  ]);
}

export function pilotCapHash({
  capId,
  assetId,
  maxAmount,
  usedAmount,
  unit,
  windowStartsAtUnixMs,
  windowEndsAtUnixMs,
  realValuePilot,
  productionReady
}) {
  return typedHash(TYPE_STRINGS.pilotCapV0, [
    ["bytes32", capId],
    ["bytes32", assetId],
    ["uint256", maxAmount],
    ["uint256", usedAmount],
    ["bytes32", keccakUtf8(unit)],
    ["uint64", windowStartsAtUnixMs],
    ["uint64", windowEndsAtUnixMs],
    ["uint8", booleanCode(realValuePilot)],
    ["uint8", booleanCode(productionReady)]
  ]);
}

export function pilotBridgeCreditAckId({
  chainId,
  contractAddress,
  operatorId,
  creditId,
  depositId,
  accountId,
  assetId,
  amount,
  acknowledgedAtBlockNumber,
  accountNonce,
  issuedAtUnixMs,
  expiresAtUnixMs,
  pilotCap
}) {
  return typedHash(TYPE_STRINGS.pilotBridgeCreditAckV0, [
    ["uint256", chainId],
    ["address", contractAddress],
    ["bytes32", operatorId],
    ["bytes32", creditId],
    ["bytes32", depositId],
    ["bytes32", accountId],
    ["bytes32", assetId],
    ["uint256", amount],
    ["uint64", acknowledgedAtBlockNumber],
    ["uint64", accountNonce],
    ["uint64", issuedAtUnixMs],
    ["uint64", expiresAtUnixMs],
    ["bytes32", pilotCapHash(pilotCap)]
  ]);
}

export function pilotWithdrawalIntentId({
  sourceChainId,
  destinationChainId,
  contractAddress,
  operatorId,
  creditId,
  depositId,
  token,
  amount,
  flowchainAccount,
  baseRecipient,
  status,
  requestedAt,
  accountNonce,
  issuedAtUnixMs,
  expiresAtUnixMs,
  pilotCap
}) {
  return typedHash(TYPE_STRINGS.pilotWithdrawalIntentV0, [
    ["uint256", sourceChainId],
    ["uint256", destinationChainId],
    ["address", contractAddress],
    ["bytes32", operatorId],
    ["bytes32", creditId],
    ["bytes32", depositId],
    ["address", token],
    ["uint256", amount],
    ["bytes32", flowchainAccount],
    ["address", baseRecipient],
    ["bytes32", keccakUtf8(status)],
    ["bytes32", keccakUtf8(requestedAt)],
    ["uint64", accountNonce],
    ["uint64", issuedAtUnixMs],
    ["uint64", expiresAtUnixMs],
    ["bytes32", pilotCapHash(pilotCap)]
  ]);
}

export function pilotReleaseEvidenceId({
  chainId,
  contractAddress,
  operatorId,
  withdrawalIntentId,
  releaseTxHash,
  releaseLogIndex,
  token,
  amount,
  recipient,
  releasedAtBlockNumber,
  releasedAtUnixMs,
  evidenceHash,
  issuedAtUnixMs,
  expiresAtUnixMs,
  pilotCap
}) {
  return typedHash(TYPE_STRINGS.pilotReleaseEvidenceV0, [
    ["uint256", chainId],
    ["address", contractAddress],
    ["bytes32", operatorId],
    ["bytes32", withdrawalIntentId],
    ["bytes32", releaseTxHash],
    ["uint32", releaseLogIndex],
    ["address", token],
    ["uint256", amount],
    ["address", recipient],
    ["uint64", releasedAtBlockNumber],
    ["uint64", releasedAtUnixMs],
    ["bytes32", evidenceHash],
    ["uint64", issuedAtUnixMs],
    ["uint64", expiresAtUnixMs],
    ["bytes32", pilotCapHash(pilotCap)]
  ]);
}

export function pilotEmergencyControlId({
  chainId,
  contractAddress,
  operatorId,
  action,
  targetSignerId,
  reasonHash,
  issuedAtUnixMs,
  expiresAtUnixMs,
  nonce,
  pilotCap
}) {
  return typedHash(TYPE_STRINGS.pilotEmergencyControlV0, [
    ["uint256", chainId],
    ["address", contractAddress],
    ["bytes32", operatorId],
    ["bytes32", keccakUtf8(action)],
    ["bytes32", targetSignerId],
    ["bytes32", reasonHash],
    ["uint64", issuedAtUnixMs],
    ["uint64", expiresAtUnixMs],
    ["bytes32", nonce],
    ["bytes32", pilotCapHash(pilotCap)]
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
    signerRoles: ["verifier", "validator"],
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
    signerRoles: ["verifier", "validator"],
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
    signerRoles: ["operator", "bridgeRelayer"],
    nonzeroFields: [
      "depositId",
      "txHash",
      "flowchainRecipient",
      "metadataHash"
    ],
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
      metadataHash: document.metadataHash
    }),
    id: bridgeDepositId,
    parentRootCheck(document) {
      return (
        [8453, 84532].includes(document.sourceChainId) &&
        BigInt(document.amount) > 0n &&
        Number.isInteger(document.logIndex) &&
        document.logIndex >= 0
      );
    }
  },
  "flowchain.bridge_credit.v0": {
    objectType: "bridge_credit",
    idField: "creditId",
    domainName: "bridgeCreditId",
    signerRoles: ["operator", "bridgeReleaseAuthority"],
    nonzeroFields: ["creditId", "depositId", "recipient", "assetId", "nonce"],
    input: (document) => ({
      depositId: document.depositId,
      recipient: document.recipient,
      assetId: document.assetId,
      amount: document.amount,
      creditedAtBlockNumber: document.creditedAtBlockNumber,
      creditedAtUnixMs: document.creditedAtUnixMs,
      status: document.statusCode,
      nonce: document.nonce
    }),
    id: bridgeCreditId,
    parentRootCheck(document) {
      return BigInt(document.amount) > 0n && document.statusCode === LOCAL_ALPHA_BRIDGE_STATUSES.credited;
    }
  },
  "flowchain.bridge_withdrawal.v0": {
    objectType: "bridge_withdrawal",
    idField: "withdrawalId",
    domainName: "bridgeWithdrawalId",
    signerRoles: ["agent", "operator", "user"],
    nonzeroFields: ["withdrawalId", "accountId", "metadataHash", "nonce"],
    input: (document) => ({
      accountId: document.accountId,
      destinationChainId: document.destinationChainId,
      destinationContract: document.destinationContract,
      token: document.token,
      amount: document.amount,
      recipient: document.recipient,
      requestedAtBlockNumber: document.requestedAtBlockNumber,
      requestedAtUnixMs: document.requestedAtUnixMs,
      status: document.statusCode,
      nonce: document.nonce,
      metadataHash: document.metadataHash
    }),
    id: bridgeWithdrawalId,
    parentRootCheck(document) {
      return [8453, 84532].includes(document.destinationChainId) && BigInt(document.amount) > 0n;
    }
  },
  "flowchain.local_balance_record.v0": {
    objectType: "local_balance_record",
    idField: "balanceRecordId",
    domainName: "localBalanceRecordId",
    signerRoles: ["operator", "emergencyOperator"],
    nonzeroFields: ["balanceRecordId", "accountId", "assetId", "stateRoot", "nonce"],
    input: (document) => ({
      accountId: document.accountId,
      assetId: document.assetId,
      availableAmount: document.availableAmount,
      lockedAmount: document.lockedAmount,
      lastCreditId: document.lastCreditId,
      lastWithdrawalId: document.lastWithdrawalId,
      stateRoot: document.stateRoot,
      updatedAtBlockNumber: document.updatedAtBlockNumber,
      nonce: document.nonce
    }),
    id: localBalanceRecordId,
    parentRootCheck(document) {
      return BigInt(document.availableAmount) >= 0n && BigInt(document.lockedAmount) >= 0n;
    }
  },
  "flowchain.product_transfer.v0": {
    objectType: "product_transfer",
    idField: "transferId",
    domainName: "productTransferId",
    signerRoles: ["agent", "user"],
    nonzeroFields: ["transferId", "fromAccountId", "toAccountId", "assetId"],
    input: (document) => ({
      fromAccountId: document.fromAccountId,
      toAccountId: document.toAccountId,
      assetId: document.assetId,
      amount: document.amount,
      accountNonce: document.accountNonce,
      deadlineBlock: document.deadlineBlock,
      memoHash: document.memoHash
    }),
    id: productTransferId,
    parentRootCheck(document) {
      return document.fromAccountId !== document.toAccountId && BigInt(document.amount) > 0n;
    }
  },
  "flowchain.product_token_launch.v0": {
    objectType: "product_token_launch",
    idField: "tokenLaunchId",
    domainName: "productTokenLaunchId",
    signerRoles: ["agent", "user"],
    nonzeroFields: [
      "tokenLaunchId",
      "issuerAccountId",
      "tokenId",
      "symbolHash",
      "nameHash",
      "metadataHash",
      "recipientAccountId",
      "launchPolicyHash"
    ],
    input: (document) => ({
      issuerAccountId: document.issuerAccountId,
      tokenId: document.tokenId,
      symbolHash: document.symbolHash,
      nameHash: document.nameHash,
      metadataHash: document.metadataHash,
      decimals: document.decimals,
      initialSupply: document.initialSupply,
      recipientAccountId: document.recipientAccountId,
      accountNonce: document.accountNonce,
      launchPolicyHash: document.launchPolicyHash
    }),
    id: productTokenLaunchId,
    parentRootCheck(document) {
      return Number.isInteger(document.decimals) && document.decimals <= 18 && BigInt(document.initialSupply) > 0n;
    }
  },
  "flowchain.product_pool_create.v0": {
    objectType: "product_pool_create",
    idField: "poolCreateId",
    domainName: "productPoolCreateId",
    signerRoles: ["agent", "user"],
    nonzeroFields: ["poolCreateId", "creatorAccountId", "poolId", "baseAssetId", "quoteAssetId", "metadataHash"],
    input: (document) => ({
      creatorAccountId: document.creatorAccountId,
      poolId: document.poolId,
      baseAssetId: document.baseAssetId,
      quoteAssetId: document.quoteAssetId,
      feeBps: document.feeBps,
      tickSpacing: document.tickSpacing,
      metadataHash: document.metadataHash,
      accountNonce: document.accountNonce
    }),
    id: productPoolCreateId,
    parentRootCheck(document) {
      return (
        document.baseAssetId !== document.quoteAssetId &&
        Number.isInteger(document.feeBps) &&
        document.feeBps >= 0 &&
        document.feeBps <= 10000 &&
        Number.isInteger(document.tickSpacing) &&
        document.tickSpacing > 0
      );
    }
  },
  "flowchain.product_add_liquidity.v0": {
    objectType: "product_add_liquidity",
    idField: "addLiquidityId",
    domainName: "productAddLiquidityId",
    signerRoles: ["agent", "user"],
    nonzeroFields: ["addLiquidityId", "providerAccountId", "poolId"],
    input: (document) => ({
      providerAccountId: document.providerAccountId,
      poolId: document.poolId,
      baseAmount: document.baseAmount,
      quoteAmount: document.quoteAmount,
      minLiquidityTokens: document.minLiquidityTokens,
      deadlineBlock: document.deadlineBlock,
      accountNonce: document.accountNonce
    }),
    id: productAddLiquidityId,
    parentRootCheck(document) {
      return BigInt(document.baseAmount) > 0n && BigInt(document.quoteAmount) > 0n;
    }
  },
  "flowchain.product_remove_liquidity.v0": {
    objectType: "product_remove_liquidity",
    idField: "removeLiquidityId",
    domainName: "productRemoveLiquidityId",
    signerRoles: ["agent", "user"],
    nonzeroFields: ["removeLiquidityId", "providerAccountId", "poolId"],
    input: (document) => ({
      providerAccountId: document.providerAccountId,
      poolId: document.poolId,
      liquidityTokens: document.liquidityTokens,
      minBaseAmount: document.minBaseAmount,
      minQuoteAmount: document.minQuoteAmount,
      deadlineBlock: document.deadlineBlock,
      accountNonce: document.accountNonce
    }),
    id: productRemoveLiquidityId,
    parentRootCheck(document) {
      return BigInt(document.liquidityTokens) > 0n;
    }
  },
  "flowchain.product_swap.v0": {
    objectType: "product_swap",
    idField: "swapId",
    domainName: "productSwapId",
    signerRoles: ["agent", "user"],
    nonzeroFields: ["swapId", "traderAccountId", "poolId", "assetInId", "assetOutId"],
    input: (document) => ({
      traderAccountId: document.traderAccountId,
      poolId: document.poolId,
      assetInId: document.assetInId,
      assetOutId: document.assetOutId,
      amountIn: document.amountIn,
      minAmountOut: document.minAmountOut,
      deadlineBlock: document.deadlineBlock,
      accountNonce: document.accountNonce
    }),
    id: productSwapId,
    parentRootCheck(document) {
      return document.assetInId !== document.assetOutId && BigInt(document.amountIn) > 0n;
    }
  },
  "flowchain.product_bridge_credit_ack.v0": {
    objectType: "product_bridge_credit_ack",
    idField: "bridgeCreditAckId",
    domainName: "productBridgeCreditAckId",
    signerRoles: ["agent", "user"],
    nonzeroFields: ["bridgeCreditAckId", "creditId", "depositId", "accountId", "assetId"],
    input: (document) => ({
      creditId: document.creditId,
      depositId: document.depositId,
      accountId: document.accountId,
      assetId: document.assetId,
      amount: document.amount,
      acknowledgedAtBlockNumber: document.acknowledgedAtBlockNumber,
      accountNonce: document.accountNonce
    }),
    id: productBridgeCreditAckId,
    parentRootCheck(document) {
      return BigInt(document.amount) > 0n;
    }
  },
  "flowmemory.bridge_withdrawal_intent.v0": {
    objectType: "bridge_withdrawal_intent",
    idField: "withdrawalIntentId",
    domainName: "bridgeWithdrawalIntentId",
    signerRoles: ["agent", "user"],
    nonzeroFields: ["withdrawalIntentId", "creditId", "depositId", "flowchainAccount"],
    input: (document) => ({
      creditId: document.creditId,
      depositId: document.depositId,
      sourceChainId: document.sourceChainId,
      destinationChainId: document.destinationChainId,
      token: document.token,
      amount: document.amount,
      flowchainAccount: document.flowchainAccount,
      baseRecipient: document.baseRecipient,
      status: document.status,
      requestedAt: document.requestedAt,
      testMode: document.testMode,
      broadcast: document.broadcast,
      releasePolicy: document.releasePolicy,
      productionReady: document.productionReady
    }),
    id: bridgeWithdrawalIntentId,
    parentRootCheck(document) {
      return (
        [31337, 8453, 84532].includes(document.sourceChainId) &&
        [31337, 8453, 84532].includes(document.destinationChainId) &&
        BigInt(document.amount) > 0n &&
        document.testMode === true &&
        document.broadcast === false &&
        document.productionReady === false
      );
    }
  },
  "flowchain.pilot_bridge_credit_ack.v0": {
    objectType: "pilot_bridge_credit_ack",
    idField: "pilotBridgeCreditAckId",
    domainName: "pilotBridgeCreditAckId",
    signerRoles: ["operator", "bridgeReleaseAuthority"],
    nonzeroFields: [
      "pilotBridgeCreditAckId",
      "operatorId",
      "creditId",
      "depositId",
      "accountId",
      "assetId"
    ],
    input: (document) => ({
      chainId: document.chainId,
      contractAddress: document.contractAddress,
      operatorId: document.operatorId,
      creditId: document.creditId,
      depositId: document.depositId,
      accountId: document.accountId,
      assetId: document.assetId,
      amount: document.amount,
      acknowledgedAtBlockNumber: document.acknowledgedAtBlockNumber,
      accountNonce: document.accountNonce,
      issuedAtUnixMs: document.issuedAtUnixMs,
      expiresAtUnixMs: document.expiresAtUnixMs,
      pilotCap: document.pilotCap
    }),
    id: pilotBridgeCreditAckId,
    parentRootCheck(document) {
      return (
        [31337, 8453, 84532].includes(document.chainId) &&
        BigInt(document.amount) > 0n &&
        hasPilotCap(document.pilotCap)
      );
    }
  },
  "flowchain.pilot_withdrawal_intent.v0": {
    objectType: "pilot_withdrawal_intent",
    idField: "pilotWithdrawalIntentId",
    domainName: "pilotWithdrawalIntentId",
    signerRoles: ["operator", "bridgeReleaseAuthority"],
    nonzeroFields: [
      "pilotWithdrawalIntentId",
      "operatorId",
      "creditId",
      "depositId",
      "flowchainAccount"
    ],
    input: (document) => ({
      sourceChainId: document.sourceChainId,
      destinationChainId: document.destinationChainId,
      contractAddress: document.contractAddress,
      operatorId: document.operatorId,
      creditId: document.creditId,
      depositId: document.depositId,
      token: document.token,
      amount: document.amount,
      flowchainAccount: document.flowchainAccount,
      baseRecipient: document.baseRecipient,
      status: document.status,
      requestedAt: document.requestedAt,
      accountNonce: document.accountNonce,
      issuedAtUnixMs: document.issuedAtUnixMs,
      expiresAtUnixMs: document.expiresAtUnixMs,
      pilotCap: document.pilotCap
    }),
    id: pilotWithdrawalIntentId,
    parentRootCheck(document) {
      return (
        [31337, 8453, 84532].includes(document.sourceChainId) &&
        [31337, 8453, 84532].includes(document.destinationChainId) &&
        BigInt(document.amount) > 0n &&
        document.status === "requested" &&
        hasPilotCap(document.pilotCap)
      );
    }
  },
  "flowchain.pilot_release_evidence.v0": {
    objectType: "pilot_release_evidence",
    idField: "pilotReleaseEvidenceId",
    domainName: "pilotReleaseEvidenceId",
    signerRoles: ["operator", "bridgeReleaseAuthority"],
    nonzeroFields: [
      "pilotReleaseEvidenceId",
      "operatorId",
      "withdrawalIntentId",
      "releaseTxHash",
      "evidenceHash"
    ],
    input: (document) => ({
      chainId: document.chainId,
      contractAddress: document.contractAddress,
      operatorId: document.operatorId,
      withdrawalIntentId: document.withdrawalIntentId,
      releaseTxHash: document.releaseTxHash,
      releaseLogIndex: document.releaseLogIndex,
      token: document.token,
      amount: document.amount,
      recipient: document.recipient,
      releasedAtBlockNumber: document.releasedAtBlockNumber,
      releasedAtUnixMs: document.releasedAtUnixMs,
      evidenceHash: document.evidenceHash,
      issuedAtUnixMs: document.issuedAtUnixMs,
      expiresAtUnixMs: document.expiresAtUnixMs,
      pilotCap: document.pilotCap
    }),
    id: pilotReleaseEvidenceId,
    parentRootCheck(document) {
      return (
        [31337, 8453, 84532].includes(document.chainId) &&
        BigInt(document.amount) > 0n &&
        Number.isInteger(document.releaseLogIndex) &&
        document.releaseLogIndex >= 0 &&
        hasPilotCap(document.pilotCap)
      );
    }
  },
  "flowchain.pilot_emergency_control.v0": {
    objectType: "pilot_emergency_control",
    idField: "pilotEmergencyControlId",
    domainName: "pilotEmergencyControlId",
    signerRoles: ["operator", "emergencyOperator"],
    nonzeroFields: [
      "pilotEmergencyControlId",
      "operatorId",
      "targetSignerId",
      "reasonHash",
      "nonce"
    ],
    input: (document) => ({
      chainId: document.chainId,
      contractAddress: document.contractAddress,
      operatorId: document.operatorId,
      action: document.action,
      targetSignerId: document.targetSignerId,
      reasonHash: document.reasonHash,
      issuedAtUnixMs: document.issuedAtUnixMs,
      expiresAtUnixMs: document.expiresAtUnixMs,
      nonce: document.nonce,
      pilotCap: document.pilotCap
    }),
    id: pilotEmergencyControlId,
    parentRootCheck(document) {
      return (
        [31337, 8453, 84532].includes(document.chainId) &&
        ["pause", "revoke"].includes(document.action) &&
        BigInt(document.expiresAtUnixMs) >= BigInt(document.issuedAtUnixMs) &&
        hasPilotCap(document.pilotCap)
      );
    }
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

  if (descriptor.parentRootCheck) {
    try {
      if (!descriptor.parentRootCheck(document)) {
        errors.push(descriptor.objectType === "bridge_deposit" ? "malformed-bridge-deposit" : "bad-parent-root");
      }
    } catch {
      errors.push(descriptor.objectType === "bridge_deposit" ? "malformed-bridge-deposit" : "bad-parent-root");
    }
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

function classifyObjectError(error) {
  if (/hex|bytes/i.test(String(error?.message))) {
    return "malformed-id";
  }
  return "invalid-object";
}

function hasPilotCap(cap) {
  if (!cap || typeof cap !== "object") {
    return false;
  }
  return (
    isHex32(cap.capId) &&
    isHex32(cap.assetId) &&
    typeof cap.maxAmount === "string" &&
    typeof cap.usedAmount === "string" &&
    typeof cap.unit === "string" &&
    typeof cap.windowStartsAtUnixMs === "string" &&
    typeof cap.windowEndsAtUnixMs === "string" &&
    cap.realValuePilot === true &&
    cap.productionReady === false &&
    BigInt(cap.maxAmount) > 0n &&
    BigInt(cap.usedAmount) >= 0n &&
    BigInt(cap.usedAmount) <= BigInt(cap.maxAmount) &&
    BigInt(cap.windowEndsAtUnixMs) > BigInt(cap.windowStartsAtUnixMs)
  );
}

function booleanCode(value) {
  return value === true ? 1 : 0;
}
