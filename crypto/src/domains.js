import { TYPE_STRINGS } from "./constants.js";
import { typedHash } from "./hashes.js";

export function indexerCursorId({ sourceId, streamId, sequence, observationId, previousCursorId }) {
  return typedHash(TYPE_STRINGS.indexerCursorV0, [
    ["bytes32", sourceId],
    ["bytes32", streamId],
    ["uint64", sequence],
    ["bytes32", observationId],
    ["bytes32", previousCursorId]
  ]);
}

export const cursorId = indexerCursorId;

export function rootfieldNamespaceId({ chainId, registry, rootfieldId, schemaHash }) {
  return typedHash(TYPE_STRINGS.rootfieldNamespaceV0, [
    ["uint256", chainId],
    ["address", registry],
    ["bytes32", rootfieldId],
    ["bytes32", schemaHash]
  ]);
}

export function rootCommitment({ rootfieldId, root, artifactCommitment, parentPulseId, sequence }) {
  return typedHash(TYPE_STRINGS.rootCommitmentV0, [
    ["bytes32", rootfieldId],
    ["bytes32", root],
    ["bytes32", artifactCommitment],
    ["bytes32", parentPulseId],
    ["uint64", sequence]
  ]);
}

export function workReceiptId({ observationId, receiptHash, workerId, workerSequence, nonce }) {
  return typedHash(TYPE_STRINGS.workReceiptV0, [
    ["bytes32", observationId],
    ["bytes32", receiptHash],
    ["bytes32", workerId],
    ["uint64", workerSequence],
    ["bytes32", nonce]
  ]);
}

export function workerIdentity({ operatorId, workerKeyId, scopeHash }) {
  return typedHash(TYPE_STRINGS.workerIdentityV0, [
    ["bytes32", operatorId],
    ["bytes32", workerKeyId],
    ["bytes32", scopeHash]
  ]);
}

export function verifierIdentity({ operatorId, verifierKeyId, verifierSetRoot }) {
  return typedHash(TYPE_STRINGS.verifierIdentityV0, [
    ["bytes32", operatorId],
    ["bytes32", verifierKeyId],
    ["bytes32", verifierSetRoot]
  ]);
}

export function localRuntimeBlockHash({ chainId, blockNumber, parentHash, stateRoot, timestamp }) {
  return typedHash(TYPE_STRINGS.localRuntimeBlockHashV0, [
    ["uint256", chainId],
    ["uint64", blockNumber],
    ["bytes32", parentHash],
    ["bytes32", stateRoot],
    ["uint64", timestamp]
  ]);
}
