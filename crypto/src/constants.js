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
  localRuntimeBlockHashV0:
    "FlowMemoryLocalRuntimeBlockV0(uint256 chainId,uint64 blockNumber,bytes32 parentHash,bytes32 stateRoot,uint64 timestamp)",
  agentAccountV0:
    "FlowMemoryAgentAccountV0(bytes32 namespaceId,address owner,bytes32 policyRoot,bytes32 toolPermissionsRoot,bytes32 modelAllowlistRoot,bytes32 memoryNamespaceRoot,uint256 spendingLimitPerEpoch,bytes32 nonce)",
  modelPassportV0:
    "FlowMemoryModelPassportV0(bytes32 providerHash,bytes32 modelFamilyHash,bytes32 versionHash,bytes32 licenseRoot,bytes32 policyRoot,bytes32 artifactRoot,bytes32 metadataHash,bytes32 nonce)",
  memoryCellV0:
    "FlowMemoryMemoryCellV0(bytes32 ownerAgentId,bytes32 currentMemoryRoot,bytes32 previousMemoryRoot,bytes32 lastDeltaRoot,bytes32 sourceReceiptsRoot,bytes32 dependencyRoot,uint64 updatedAtUnixMs,uint16 cellVersion)",
  artifactAvailabilityProofV0:
    "FlowMemoryArtifactAvailabilityProofV0(bytes32 artifactRoot,bytes32 providerId,bytes32 locationCommitment,bytes32 storageReceiptCommitment,bytes32 availabilitySampleRoot,uint64 issuedAtUnixMs,uint64 expiresAtUnixMs,uint8 status,bytes32 nonce)",
  verifierModuleV0:
    "FlowMemoryVerifierModuleV0(bytes32 ownerId,bytes32 codeRoot,bytes32 manifestRoot,bytes32 supportedModesRoot,bytes32 supportedChallengeTypesRoot,bytes32 verifierSetRoot,uint16 moduleVersion,uint8 status)",
  challengeV0:
    "FlowMemoryChallengeV0(bytes32 receiptId,bytes32 challengerId,uint8 challengeType,bytes32 evidenceRoot,uint64 openedAtUnixMs,uint64 deadlineUnixMs,uint8 status,bytes32 nonce)",
  finalityReceiptV0:
    "FlowMemoryFinalityReceiptV0(bytes32 receiptId,bytes32 reportId,bytes32 challengeRoot,uint8 finalityState,uint64 finalizedAtUnixMs,uint64 finalizedBlockNumber,bytes32 finalizedBlockHash,bytes32 policyHash)",
  bridgeDepositV0:
    "FlowMemoryBridgeDepositV0(uint256 sourceChainId,address sourceContract,bytes32 txHash,uint32 logIndex,address token,uint256 amount,address sender,bytes32 flowmemoryRecipient,uint256 nonce,bytes32 metadataHash)",
  bridgeCreditV0:
    "FlowMemoryBridgeCreditV0(bytes32 depositId,bytes32 recipient,bytes32 assetId,uint256 amount,uint64 creditedAtBlockNumber,uint64 creditedAtUnixMs,uint8 status,bytes32 nonce)",
  bridgeWithdrawalV0:
    "FlowMemoryBridgeWithdrawalV0(bytes32 accountId,uint256 destinationChainId,address destinationContract,address token,uint256 amount,address recipient,uint64 requestedAtBlockNumber,uint64 requestedAtUnixMs,uint8 status,bytes32 nonce,bytes32 metadataHash)",
  localBalanceRecordV0:
    "FlowMemoryLocalBalanceRecordV0(bytes32 accountId,bytes32 assetId,uint256 availableAmount,uint256 lockedAmount,bytes32 lastCreditId,bytes32 lastWithdrawalId,bytes32 stateRoot,uint64 updatedAtBlockNumber,bytes32 nonce)",
  productTransferV0:
    "FlowMemoryProductTransferV0(bytes32 fromAccountId,bytes32 toAccountId,bytes32 assetId,uint256 amount,uint64 accountNonce,uint64 deadlineBlock,bytes32 memoHash)",
  productTokenLaunchV0:
    "FlowMemoryProductTokenLaunchV0(bytes32 issuerAccountId,bytes32 tokenId,bytes32 symbolHash,bytes32 nameHash,bytes32 metadataHash,uint8 decimals,uint256 initialSupply,bytes32 recipientAccountId,uint64 accountNonce,bytes32 launchPolicyHash)",
  productPoolCreateV0:
    "FlowMemoryProductPoolCreateV0(bytes32 creatorAccountId,bytes32 poolId,bytes32 baseAssetId,bytes32 quoteAssetId,uint32 feeBps,uint32 tickSpacing,bytes32 metadataHash,uint64 accountNonce)",
  productAddLiquidityV0:
    "FlowMemoryProductAddLiquidityV0(bytes32 providerAccountId,bytes32 poolId,uint256 baseAmount,uint256 quoteAmount,uint256 minLiquidityTokens,uint64 deadlineBlock,uint64 accountNonce)",
  productRemoveLiquidityV0:
    "FlowMemoryProductRemoveLiquidityV0(bytes32 providerAccountId,bytes32 poolId,uint256 liquidityTokens,uint256 minBaseAmount,uint256 minQuoteAmount,uint64 deadlineBlock,uint64 accountNonce)",
  productSwapV0:
    "FlowMemoryProductSwapV0(bytes32 traderAccountId,bytes32 poolId,bytes32 assetInId,bytes32 assetOutId,uint256 amountIn,uint256 minAmountOut,uint64 deadlineBlock,uint64 accountNonce)",
  productBridgeCreditAckV0:
    "FlowMemoryProductBridgeCreditAckV0(bytes32 creditId,bytes32 depositId,bytes32 accountId,bytes32 assetId,uint256 amount,uint64 acknowledgedAtBlockNumber,uint64 accountNonce)",
  bridgeWithdrawalIntentV0:
    "FlowMemoryBridgeWithdrawalIntentV0(bytes32 creditId,bytes32 depositId,uint256 sourceChainId,uint256 destinationChainId,address token,uint256 amount,bytes32 flowmemoryAccount,address baseRecipient,bytes32 statusHash,bytes32 requestedAtHash,uint8 testMode,uint8 broadcast,bytes32 releasePolicyHash,uint8 productionReady)",
  pilotCapV0:
    "FlowMemoryPilotCapV0(bytes32 capId,bytes32 assetId,uint256 maxAmount,uint256 usedAmount,bytes32 unitHash,uint64 windowStartsAtUnixMs,uint64 windowEndsAtUnixMs,uint8 realValuePilot,uint8 productionReady)",
  pilotBridgeCreditAckV0:
    "FlowMemoryPilotBridgeCreditAckV0(uint256 chainId,address contractAddress,bytes32 operatorId,bytes32 creditId,bytes32 depositId,bytes32 accountId,bytes32 assetId,uint256 amount,uint64 acknowledgedAtBlockNumber,uint64 accountNonce,uint64 issuedAtUnixMs,uint64 expiresAtUnixMs,bytes32 capHash)",
  pilotWithdrawalIntentV0:
    "FlowMemoryPilotWithdrawalIntentV0(uint256 sourceChainId,uint256 destinationChainId,address contractAddress,bytes32 operatorId,bytes32 creditId,bytes32 depositId,address token,uint256 amount,bytes32 flowmemoryAccount,address baseRecipient,bytes32 statusHash,bytes32 requestedAtHash,uint64 accountNonce,uint64 issuedAtUnixMs,uint64 expiresAtUnixMs,bytes32 capHash)",
  pilotReleaseEvidenceV0:
    "FlowMemoryPilotReleaseEvidenceV0(uint256 chainId,address contractAddress,bytes32 operatorId,bytes32 withdrawalIntentId,bytes32 releaseTxHash,uint32 releaseLogIndex,address token,uint256 amount,address recipient,uint64 releasedAtBlockNumber,uint64 releasedAtUnixMs,bytes32 evidenceHash,uint64 issuedAtUnixMs,uint64 expiresAtUnixMs,bytes32 capHash)",
  pilotEmergencyControlV0:
    "FlowMemoryPilotEmergencyControlV0(uint256 chainId,address contractAddress,bytes32 operatorId,bytes32 actionHash,bytes32 targetSignerId,bytes32 reasonHash,uint64 issuedAtUnixMs,uint64 expiresAtUnixMs,bytes32 nonce,bytes32 capHash)",
  hardwareSignalEnvelopeV0:
    "FlowMemoryHardwareSignalEnvelopeV0(bytes32 deviceId,bytes32 signalRoot,bytes32 previousSignalEnvelopeId,bytes32 channelRoot,uint64 sequence,uint64 observedAtUnixMs,uint8 transport,bytes32 nonce)",
  controlPlaneProvenanceResponseV0:
    "FlowMemoryControlPlaneProvenanceResponseV0(bytes32 requestId,bytes32 subjectId,bytes32 agentId,bytes32 receiptId,bytes32 reportId,bytes32 memoryCellId,bytes32 dependencyRoot,bytes32 responseBodyHash,uint64 issuedAtUnixMs,uint16 responseVersion)",
  localSignatureEnvelopeV0:
    "FlowMemoryLocalSignatureEnvelopeV0(bytes32 objectId,bytes32 objectTypeHash,bytes32 domainSeparator,bytes32 signerId,bytes32 signerKeyId,uint8 signerRole,uint64 sequence,uint64 issuedAtUnixMs,uint64 expiresAtUnixMs,bytes32 nonce)",
  localTransactionEnvelopeV0:
    "FlowMemoryLocalTransactionEnvelopeV0(uint256 chainId,bytes32 domainSeparator,bytes32 signerId,bytes32 signerKeyId,uint8 signerRole,uint64 nonce,bytes32 payloadHash,bytes32 objectId,bytes32 objectTypeHash,uint64 issuedAtUnixMs)",
  localTransactionEnvelopeProductionNetworkV0:
    "FlowMemoryLocalTransactionEnvelopeProductionNetworkV0(uint16 schemaVersion,uint256 chainId,bytes32 networkProfileHash,bytes32 domainSeparator,bytes32 signerId,bytes32 signerKeyId,uint8 signerRole,uint64 nonce,bytes32 payloadTypeHash,bytes32 payloadHash,bytes32 objectId,bytes32 objectTypeHash,uint64 issuedAtUnixMs,uint64 expiresAtUnixMs,bytes32 localExecutionCostHash,bytes32 feeHash,bytes32 signatureAlgorithmHash)",
  flowmemoryTransactionIdV0:
    "FlowMemoryTransactionIdV0(uint256 chainId,bytes32 networkProfileHash,bytes32 envelopeId,bytes32 payloadHash,bytes32 signatureHash)",
  flowmemoryAccountIdV0:
    "FlowMemoryAccountIdV0(bytes32 publicKeyHash,address flowmemoryAddress,bytes32 roleRoot)",
  flowmemoryBridgeObservationV0:
    "FlowMemoryBridgeObservationV0(uint256 sourceChainId,address lockbox,address token,address depositor,bytes32 recipient,uint256 amount,bytes32 txHash,uint32 logIndex,uint64 blockNumber,uint256 eventNonce)",
  flowmemoryBridgeSourceEventReplayKeyV0:
    "FlowMemoryBridgeSourceEventReplayKeyV0(uint256 sourceChainId,address lockbox,bytes32 txHash,uint32 logIndex)",
  flowmemoryBridgeEvidenceHashV0:
    "FlowMemoryBridgeEvidenceHashV0(bytes32 sourceEventReplayKey,bytes32 observationId,bytes32 creditId,bytes32 depositId,uint256 localChainId,bytes32 evidencePayloadHash)",
  flowmemoryBridgeCreditV1:
    "FlowMemoryBridgeCreditV1(bytes32 observationId,bytes32 localRecipient,uint256 localChainId,uint256 creditAmount)",
  flowmemoryWithdrawalIntentV1:
    "FlowMemoryWithdrawalIntentV1(uint256 localChainId,bytes32 accountId,bytes32 assetId,uint256 amount,uint64 nonce,bytes32 destinationHash)",
  flowmemoryFinalityReceiptV1:
    "FlowMemoryFinalityReceiptV1(uint256 chainId,uint64 blockNumber,bytes32 blockHash,bytes32 stateRoot,bytes32 validatorSetRoot,uint64 round,bytes32 voteRoot)",
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
  localRuntimeBlockHash: "flowmemory.v0.localRuntime.block-hash",
  agentAccountId: "flowmemory.local-alpha.v0.agent-account.id",
  modelPassportId: "flowmemory.local-alpha.v0.model-passport.id",
  memoryCellId: "flowmemory.local-alpha.v0.memory-cell.id",
  artifactAvailabilityProofId: "flowmemory.local-alpha.v0.artifact-availability-proof.id",
  verifierModuleId: "flowmemory.local-alpha.v0.verifier-module.id",
  challengeId: "flowmemory.local-alpha.v0.challenge.id",
  finalityReceiptId: "flowmemory.local-alpha.v0.finality-receipt.id",
  bridgeDepositId: "flowmemory.local-alpha.v0.bridge-deposit.id",
  bridgeCreditId: "flowmemory.local-alpha.v0.bridge-credit.id",
  bridgeWithdrawalId: "flowmemory.local-alpha.v0.bridge-withdrawal.id",
  localBalanceRecordId: "flowmemory.local-alpha.v0.local-balance-record.id",
  productTransferId: "flowmemory.product-testnet.v1.transfer.id",
  productTokenLaunchId: "flowmemory.product-testnet.v1.token-launch.id",
  productPoolCreateId: "flowmemory.product-testnet.v1.pool-create.id",
  productAddLiquidityId: "flowmemory.product-testnet.v1.add-liquidity.id",
  productRemoveLiquidityId: "flowmemory.product-testnet.v1.remove-liquidity.id",
  productSwapId: "flowmemory.product-testnet.v1.swap.id",
  productBridgeCreditAckId: "flowmemory.product-testnet.v1.bridge-credit-ack.id",
  bridgeWithdrawalIntentId: "flowmemory.product-testnet.v1.bridge-withdrawal-intent.id",
  pilotCapId: "flowmemory.real-value-pilot.v0.cap.id",
  pilotBridgeCreditAckId: "flowmemory.real-value-pilot.v0.bridge-credit-ack.id",
  pilotWithdrawalIntentId: "flowmemory.real-value-pilot.v0.withdrawal-intent.id",
  pilotReleaseEvidenceId: "flowmemory.real-value-pilot.v0.release-evidence.id",
  pilotEmergencyControlId: "flowmemory.real-value-pilot.v0.emergency-control.id",
  hardwareSignalEnvelopeId: "flowmemory.local-alpha.v0.hardware-signal-envelope.id",
  controlPlaneProvenanceResponseId: "flowmemory.local-alpha.v0.control-plane-provenance-response.id",
  localSignatureEnvelope: "flowmemory.local-alpha.v0.local-signature-envelope",
  localTransactionEnvelope: "flowmemory.local-alpha.v0.local-transaction-envelope",
  productionNetworkTransactionEnvelope: "flowmemory.production-network.v0.transaction-envelope",
  productionLocalChain: "flowmemory.production-network.v0.local-chain",
  productionPrivateLan: "flowmemory.production-network.v0.private-lan",
  productionBase8453PilotBridge: "flowmemory.production-network.v0.base-8453-pilot-bridge",
  productionObjectLifecycle: "flowmemory.production-network.v0.object-lifecycle",
  productionTokenDex: "flowmemory.production-network.v0.token-dex",
  productionValidatorFinality: "flowmemory.production-network.v0.validator-finality",
  productionAccountIdentity: "flowmemory.production-network.v0.account-identity",
  productionAddress: "flowmemory.production-network.v0.address",
  productionBridgeObservation: "flowmemory.production-network.v0.bridge-observation",
  productionBridgeCredit: "flowmemory.production-network.v0.bridge-credit",
  productionWithdrawalIntent: "flowmemory.production-network.v0.withdrawal-intent",
  productionFinalityReceipt: "flowmemory.production-network.v0.finality-receipt"
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

export const LOCAL_ALPHA_OBJECT_STATUSES = Object.freeze({
  draft: 1,
  active: 2,
  paused: 3,
  revoked: 4,
  deprecated: 5,
  rejected: 6,
  available: 7,
  unavailable: 8,
  expired: 9
});

export const LOCAL_ALPHA_CHALLENGE_TYPES = Object.freeze({
  missingArtifact: 1,
  invalidArtifactRoot: 2,
  missingModelPassport: 3,
  memoryParentMismatch: 4,
  policyViolation: 5,
  deterministicReplayFailure: 6,
  dependencyOmission: 7
});

export const LOCAL_ALPHA_CHALLENGE_STATUSES = Object.freeze({
  open: 1,
  submitterWins: 2,
  challengerWins: 3,
  unresolved: 4,
  expired: 5
});

export const LOCAL_ALPHA_FINALITY_STATES = Object.freeze({
  provisional: 1,
  challengeable: 2,
  challenged: 3,
  accepted: 4,
  rejected: 5,
  finalized: 6,
  superseded: 7,
  reorged: 8
});

export const LOCAL_ALPHA_HARDWARE_TRANSPORTS = Object.freeze({
  localSimulator: 1,
  usbSerial: 2,
  loraControl: 3,
  meshtasticControl: 4
});

export const LOCAL_ALPHA_SIGNER_ROLES = Object.freeze({
  operator: 1,
  agent: 2,
  verifier: 3,
  hardware: 4,
  user: 10,
  validator: 11,
  bridgeRelayer: 12,
  bridgeReleaseAuthority: 13,
  emergencyOperator: 14
});

export const FLOWMEMORY_ACCOUNT_ROLES = Object.freeze({
  user: {
    code: LOCAL_ALPHA_SIGNER_ROLES.user,
    roleGated: false,
    description: "Normal account authority for user-owned local/private transactions."
  },
  validator: {
    code: LOCAL_ALPHA_SIGNER_ROLES.validator,
    roleGated: true,
    description: "Validator/finality authority for local/private finality objects."
  },
  bridgeRelayer: {
    code: LOCAL_ALPHA_SIGNER_ROLES.bridgeRelayer,
    roleGated: true,
    description: "Bridge observation submitter for source-event facts."
  },
  bridgeReleaseAuthority: {
    code: LOCAL_ALPHA_SIGNER_ROLES.bridgeReleaseAuthority,
    roleGated: true,
    description: "Bridge credit and release authority for local/private bridge accounting."
  },
  emergencyOperator: {
    code: LOCAL_ALPHA_SIGNER_ROLES.emergencyOperator,
    roleGated: true,
    description: "Emergency operator for pause, revoke, and recovery controls."
  }
});

export const LOCAL_ALPHA_BRIDGE_STATUSES = Object.freeze({
  observed: 1,
  acceptedLocal: 2,
  credited: 3,
  withdrawalRequested: 4,
  released: 5,
  rejected: 6,
  failed: 7
});
