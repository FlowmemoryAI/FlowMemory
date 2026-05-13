export const ZERO_BYTES32 = "0x0000000000000000000000000000000000000000000000000000000000000000";

export const FLOWPULSE_SCHEMA_ID_PREIMAGE = "flowmemory.flowpulse.v0";
export const FLOWPULSE_EVENT_SIGNATURE =
  "FlowPulse(bytes32,bytes32,address,uint8,bytes32,bytes32,bytes32,uint64,uint64,string)";

export const TYPE_STRINGS = Object.freeze({
  indexerCursorV0:
    "FlowMemoryIndexerCursorV0(bytes32 sourceId,bytes32 streamId,uint64 sequence,bytes32 observationId,bytes32 previousCursorId)",
  flowPulseObservationV0:
    "FlowPulseObservationV0(uint256 chainId,address emittingContract,uint64 blockNumber,bytes32 blockHash,bytes32 txHash,uint32 transactionIndex,uint32 logIndex,bytes32 eventSignature,bytes32 pulseId,bytes32 rootfieldId)",
  flowPulseEventArgsV0:
    "FlowPulseEventArgsV0(bytes32 pulseId,bytes32 rootfieldId,address actor,uint8 pulseType,bytes32 subject,bytes32 commitment,bytes32 parentPulseId,uint64 sequence,uint64 occurredAt,bytes32 uriHash)",
  flowPulseReceiptV0:
    "FlowPulseReceiptV0(bytes32 observationId,bytes32 eventArgsHash,bytes32 artifactRoot,bytes32 storageReceiptCommitment,bytes32 evidenceRoot,uint16 receiptVersion)",
  artifactRootV0:
    "FlowMemoryArtifactRootV0(bytes32 schemeId,bytes32 manifestHash,bytes32 contentMerkleRoot,uint64 byteLength,uint32 chunkSize,bytes32 mediaTypeHash,bytes32 metadataHash)",
  merkleLeafV0:
    "FlowMemoryMerkleLeafV0(uint64 index,uint64 offset,uint32 length,bytes32 chunkHash)",
  merkleInternalNodeV0:
    "FlowMemoryMerkleInternalNodeV0(bytes32 leftHash,bytes32 rightHash)",
  storageReceiptCommitmentV0:
    "FlowMemoryStorageReceiptCommitmentV0(bytes32 artifactRoot,bytes32 providerId,bytes32 locationCommitment,bytes32 retentionPolicyHash,bytes32 encryptionCommitment,bytes32 availabilitySampleRoot,uint64 issuedAtUnixMs,uint64 expiresAtUnixMs,bytes32 nonce)",
  workerSignatureV0:
    "FlowMemoryWorkerSignatureV0(bytes32 receiptHash,bytes32 workerId,bytes32 workerKeyId,uint64 workerSequence,uint64 expiresAtUnixMs,bytes32 artifactRoot,bytes32 nonce)",
  verifierReportV0:
    "FlowMemoryVerifierReportV0(bytes32 reportSchemaHash,bytes32 observationId,bytes32 receiptHash,bytes32 verifierId,bytes32 verifierSetRoot,uint8 status,bytes32 checksRoot,uint64 finalizedBlockNumber,bytes32 finalizedBlockHash,uint16 reportVersion)",
  verifierSignatureV0:
    "FlowMemoryVerifierSignatureV0(bytes32 reportId,bytes32 verifierId,bytes32 verifierKeyId,bytes32 verifierSetRoot,uint64 issuedAtUnixMs,uint64 expiresAtUnixMs,bytes32 nonce)",
  attestationEnvelopeV0:
    "FlowMemoryAttestationEnvelopeV0(bytes32 subjectHash,uint8 subjectKind,bytes32 attesterId,bytes32 attesterKeyId,bytes32 verifierSetRoot,uint64 issuedAtUnixMs,uint64 expiresAtUnixMs,bytes32 nonce)",
  rootfieldNamespaceV0:
    "FlowMemoryRootfieldNamespaceV0(uint256 chainId,address registry,bytes32 rootfieldId,bytes32 schemaHash)",
  rootCommitmentV0:
    "FlowMemoryRootCommitmentV0(bytes32 rootfieldId,bytes32 root,bytes32 artifactCommitment,bytes32 parentPulseId,uint64 sequence)",
  workReceiptV0:
    "FlowMemoryWorkReceiptV0(bytes32 observationId,bytes32 receiptHash,bytes32 workerId,uint64 workerSequence,bytes32 nonce)",
  workerIdentityV0:
    "FlowMemoryWorkerIdentityV0(bytes32 operatorId,bytes32 workerKeyId,bytes32 scopeHash)",
  verifierIdentityV0:
    "FlowMemoryVerifierIdentityV0(bytes32 operatorId,bytes32 verifierKeyId,bytes32 verifierSetRoot)",
  devnetBlockHashV0:
    "FlowMemoryDevnetBlockV0(uint256 chainId,uint64 blockNumber,bytes32 parentHash,bytes32 stateRoot,uint64 timestamp)",
  eip712Domain:
    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract,bytes32 salt)"
});

export const DOMAIN_STRINGS = Object.freeze({
  flowPulseObservationId: "flowmemory.v0.flowpulse.observation-id",
  indexerCursorId: "flowmemory.v0.indexer.cursor-id",
  verifierReportDigest: "flowmemory.v0.verifier.report-digest",
  verifierAttestationEnvelope: "flowmemory.v0.verifier.attestation-envelope",
  rootfieldNamespaceId: "flowmemory.v0.rootfield.namespace-id",
  rootCommitment: "flowmemory.v0.root.commitment",
  artifactCommitment: "flowmemory.v0.artifact.commitment",
  workReceiptId: "flowmemory.v0.work.receipt-id",
  workerIdentity: "flowmemory.v0.worker.identity",
  verifierIdentity: "flowmemory.v0.verifier.identity",
  merkleLeaf: "flowmemory.v0.merkle.leaf",
  merkleInternalNode: "flowmemory.v0.merkle.internal-node",
  devnetBlockHash: "flowmemory.v0.devnet.block-hash"
});

export const MERKLE_SCHEME_V0 = "FM-MERKLE-KECCAK256-BINARY-V0";

export const VERIFIER_STATUSES = Object.freeze({
  reserved: 0,
  observed: 1,
  verified: 2,
  unresolved: 3,
  unsupported: 4,
  failed: 5,
  reorged: 6,
  superseded: 7
});
