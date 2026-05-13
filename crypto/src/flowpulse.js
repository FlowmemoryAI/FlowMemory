import {
  FLOWPULSE_EVENT_SIGNATURE,
  FLOWPULSE_SCHEMA_ID_PREIMAGE,
  TYPE_STRINGS
} from "./constants.js";
import { abiEncodeStatic, concatBytes, hexToBytes } from "./encoding.js";
import { keccak256Hex, keccakUtf8, typedHash } from "./hashes.js";

export function flowPulseSchemaId() {
  return keccakUtf8(FLOWPULSE_SCHEMA_ID_PREIMAGE);
}

export function flowPulseEventSignature() {
  return keccakUtf8(FLOWPULSE_EVENT_SIGNATURE);
}

export function contractPulseId({
  chainId,
  emittingContract,
  rootfieldId,
  actor,
  pulseType,
  subject,
  commitment,
  parentPulseId,
  sequence
}) {
  return keccak256Hex(
    abiEncodeStatic([
      ["bytes32", flowPulseSchemaId()],
      ["uint256", chainId],
      ["address", emittingContract],
      ["bytes32", rootfieldId],
      ["address", actor],
      ["uint8", pulseType],
      ["bytes32", subject],
      ["bytes32", commitment],
      ["bytes32", parentPulseId],
      ["uint64", sequence]
    ])
  );
}

export function flowPulseObservationId({
  chainId,
  emittingContract,
  blockNumber,
  blockHash,
  txHash,
  transactionIndex,
  logIndex,
  eventSignature,
  pulseId,
  rootfieldId
}) {
  return typedHash(TYPE_STRINGS.flowPulseObservationV0, [
    ["uint256", chainId],
    ["address", emittingContract],
    ["uint64", blockNumber],
    ["bytes32", blockHash],
    ["bytes32", txHash],
    ["uint32", transactionIndex],
    ["uint32", logIndex],
    ["bytes32", eventSignature],
    ["bytes32", pulseId],
    ["bytes32", rootfieldId]
  ]);
}

export function flowPulseEventArgsHash({
  pulseId,
  rootfieldId,
  actor,
  pulseType,
  subject,
  commitment,
  parentPulseId,
  sequence,
  occurredAt,
  uriHash
}) {
  return typedHash(TYPE_STRINGS.flowPulseEventArgsV0, [
    ["bytes32", pulseId],
    ["bytes32", rootfieldId],
    ["address", actor],
    ["uint8", pulseType],
    ["bytes32", subject],
    ["bytes32", commitment],
    ["bytes32", parentPulseId],
    ["uint64", sequence],
    ["uint64", occurredAt],
    ["bytes32", uriHash]
  ]);
}

export function receiptHash({
  observationId,
  eventArgsHash,
  artifactRoot,
  storageReceiptCommitment,
  evidenceRoot,
  receiptVersion
}) {
  return typedHash(TYPE_STRINGS.flowPulseReceiptV0, [
    ["bytes32", observationId],
    ["bytes32", eventArgsHash],
    ["bytes32", artifactRoot],
    ["bytes32", storageReceiptCommitment],
    ["bytes32", evidenceRoot],
    ["uint16", receiptVersion]
  ]);
}

export function verifierReportHash({
  reportSchemaHash,
  observationId,
  receiptHash,
  verifierId,
  verifierSetRoot,
  status,
  checksRoot,
  finalizedBlockNumber,
  finalizedBlockHash,
  reportVersion
}) {
  return typedHash(TYPE_STRINGS.verifierReportV0, [
    ["bytes32", reportSchemaHash],
    ["bytes32", observationId],
    ["bytes32", receiptHash],
    ["bytes32", verifierId],
    ["bytes32", verifierSetRoot],
    ["uint8", status],
    ["bytes32", checksRoot],
    ["uint64", finalizedBlockNumber],
    ["bytes32", finalizedBlockHash],
    ["uint16", reportVersion]
  ]);
}

export const reportDigest = verifierReportHash;

export function eip712Digest(domainSeparator, structHash) {
  return keccak256Hex(
    concatBytes(Uint8Array.of(0x19, 0x01), hexToBytes(domainSeparator, 32), hexToBytes(structHash, 32))
  );
}
