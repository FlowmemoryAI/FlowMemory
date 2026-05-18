export type Hex = `0x${string}`;
export type Address = Hex;
export type Bytes32 = Hex;

export interface FlowPulseContractInput {
  chainId: number | bigint | string;
  emittingContract: Address;
  rootfieldId: Bytes32;
  actor: Address;
  pulseType: number | bigint | string;
  subject: Bytes32;
  commitment: Bytes32;
  parentPulseId: Bytes32;
  sequence: number | bigint | string;
}

export interface FlowPulseEventArgsInput {
  pulseId: Bytes32;
  rootfieldId: Bytes32;
  actor: Address;
  pulseType: number | bigint | string;
  subject: Bytes32;
  commitment: Bytes32;
  parentPulseId: Bytes32;
  sequence: number | bigint | string;
  occurredAt: number | bigint | string;
  uriHash: Bytes32;
}

export interface FlowPulseObservationInput {
  chainId: number | bigint | string;
  emittingContract: Address;
  blockNumber: number | bigint | string;
  blockHash: Bytes32;
  txHash: Bytes32;
  transactionIndex: number | bigint | string;
  logIndex: number | bigint | string;
  eventSignature: Bytes32;
  pulseId: Bytes32;
  rootfieldId: Bytes32;
}

export interface ReceiptInput {
  observationId: Bytes32;
  eventArgsHash: Bytes32;
  artifactRoot: Bytes32;
  storageReceiptCommitment: Bytes32;
  evidenceRoot: Bytes32;
  receiptVersion: number | bigint | string;
}

export interface StorageReceiptCommitmentInput {
  artifactRoot: Bytes32;
  providerId: Bytes32;
  locationCommitment: Bytes32;
  retentionPolicyHash: Bytes32;
  encryptionCommitment: Bytes32;
  availabilitySampleRoot: Bytes32;
  issuedAtUnixMs: number | bigint | string;
  expiresAtUnixMs: number | bigint | string;
  nonce: Bytes32;
}

export interface VerifierReportInput {
  reportSchemaHash: Bytes32;
  observationId: Bytes32;
  receiptHash: Bytes32;
  verifierId: Bytes32;
  verifierSetRoot: Bytes32;
  status: number | bigint | string;
  checksRoot: Bytes32;
  finalizedBlockNumber: number | bigint | string;
  finalizedBlockHash: Bytes32;
  reportVersion: number | bigint | string;
}

export interface SignatureDomainInput {
  domainSeparator: Bytes32;
}

export interface WorkerSignatureInput {
  receiptHash: Bytes32;
  workerId: Bytes32;
  workerKeyId: Bytes32;
  workerSequence: number | bigint | string;
  expiresAtUnixMs: number | bigint | string;
  artifactRoot: Bytes32;
  nonce: Bytes32;
}

export interface VerifierSignatureInput {
  reportId: Bytes32;
  verifierId: Bytes32;
  verifierKeyId: Bytes32;
  verifierSetRoot: Bytes32;
  issuedAtUnixMs: number | bigint | string;
  expiresAtUnixMs: number | bigint | string;
  nonce: Bytes32;
}

export interface AttestationEnvelopeInput {
  subjectHash: Bytes32;
  subjectKind: number | bigint | string;
  attesterId: Bytes32;
  attesterKeyId: Bytes32;
  verifierSetRoot: Bytes32;
  issuedAtUnixMs: number | bigint | string;
  expiresAtUnixMs: number | bigint | string;
  nonce: Bytes32;
}

export interface MerkleLeafInput {
  index: number | bigint | string;
  offset: number | bigint | string;
  length: number | bigint | string;
  chunkHash: Bytes32;
}

export interface ArtifactInput {
  chunks: Array<string | Uint8Array>;
  chunkSize: number | bigint | string;
  mediaType: string;
  metadata: unknown;
}

export interface ArtifactOutput {
  schemeId: Bytes32;
  manifest: unknown;
  manifestHash: Bytes32;
  leafHashes: Bytes32[];
  contentMerkleRoot: Bytes32;
  metadataHash: Bytes32;
  mediaTypeHash: Bytes32;
  artifactRoot: Bytes32;
}

export interface IndexerCursorInput {
  sourceId: Bytes32;
  streamId: Bytes32;
  sequence: number | bigint | string;
  observationId: Bytes32;
  previousCursorId: Bytes32;
}

export interface RootfieldNamespaceInput {
  chainId: number | bigint | string;
  registry: Address;
  rootfieldId: Bytes32;
  schemaHash: Bytes32;
}

export interface RootCommitmentInput {
  rootfieldId: Bytes32;
  root: Bytes32;
  artifactCommitment: Bytes32;
  parentPulseId: Bytes32;
  sequence: number | bigint | string;
}

export interface WorkReceiptInput {
  observationId: Bytes32;
  receiptHash: Bytes32;
  workerId: Bytes32;
  workerSequence: number | bigint | string;
  nonce: Bytes32;
}

export interface WorkerIdentityInput {
  operatorId: Bytes32;
  workerKeyId: Bytes32;
  scopeHash: Bytes32;
}

export interface VerifierIdentityInput {
  operatorId: Bytes32;
  verifierKeyId: Bytes32;
  verifierSetRoot: Bytes32;
}

export interface DevnetBlockInput {
  chainId: number | bigint | string;
  blockNumber: number | bigint | string;
  parentHash: Bytes32;
  stateRoot: Bytes32;
  timestamp: number | bigint | string;
}

export interface AgentAccountInput {
  namespaceId: Bytes32;
  owner: Address;
  policyRoot: Bytes32;
  toolPermissionsRoot: Bytes32;
  modelAllowlistRoot: Bytes32;
  memoryNamespaceRoot: Bytes32;
  spendingLimitPerEpoch: number | bigint | string;
  nonce: Bytes32;
}

export interface ModelPassportInput {
  providerHash: Bytes32;
  modelFamilyHash: Bytes32;
  versionHash: Bytes32;
  licenseRoot: Bytes32;
  policyRoot: Bytes32;
  artifactRoot: Bytes32;
  metadataHash: Bytes32;
  nonce: Bytes32;
}

export interface MemoryCellInput {
  ownerAgentId: Bytes32;
  currentMemoryRoot: Bytes32;
  previousMemoryRoot: Bytes32;
  lastDeltaRoot: Bytes32;
  sourceReceiptsRoot: Bytes32;
  dependencyRoot: Bytes32;
  updatedAtUnixMs: number | bigint | string;
  cellVersion: number | bigint | string;
}

export interface ArtifactAvailabilityProofInput {
  artifactRoot: Bytes32;
  providerId: Bytes32;
  locationCommitment: Bytes32;
  storageReceiptCommitment: Bytes32;
  availabilitySampleRoot: Bytes32;
  issuedAtUnixMs: number | bigint | string;
  expiresAtUnixMs: number | bigint | string;
  status: number | bigint | string;
  nonce: Bytes32;
}

export interface VerifierModuleInput {
  ownerId: Bytes32;
  codeRoot: Bytes32;
  manifestRoot: Bytes32;
  supportedModesRoot: Bytes32;
  supportedChallengeTypesRoot: Bytes32;
  verifierSetRoot: Bytes32;
  moduleVersion: number | bigint | string;
  status: number | bigint | string;
}

export interface ChallengeInput {
  receiptId: Bytes32;
  challengerId: Bytes32;
  challengeType: number | bigint | string;
  evidenceRoot: Bytes32;
  openedAtUnixMs: number | bigint | string;
  deadlineUnixMs: number | bigint | string;
  status: number | bigint | string;
  nonce: Bytes32;
}

export interface FinalityReceiptInput {
  receiptId: Bytes32;
  reportId: Bytes32;
  challengeRoot: Bytes32;
  finalityState: number | bigint | string;
  finalizedAtUnixMs: number | bigint | string;
  finalizedBlockNumber: number | bigint | string;
  finalizedBlockHash: Bytes32;
  policyHash: Bytes32;
}

export interface BridgeDepositInput {
  sourceChainId: number | bigint | string;
  sourceContract: Address;
  txHash: Bytes32;
  logIndex: number | bigint | string;
  token: Address;
  amount: number | bigint | string;
  sender: Address;
  flowchainRecipient: Bytes32;
  nonce: number | bigint | string;
  metadataHash: Bytes32;
}

export interface BridgeCreditInput {
  depositId: Bytes32;
  recipient: Bytes32;
  assetId: Bytes32;
  amount: number | bigint | string;
  creditedAtBlockNumber: number | bigint | string;
  creditedAtUnixMs: number | bigint | string;
  status: number | bigint | string;
  nonce: Bytes32;
}

export interface BridgeWithdrawalInput {
  accountId: Bytes32;
  destinationChainId: number | bigint | string;
  destinationContract: Address;
  token: Address;
  amount: number | bigint | string;
  recipient: Address;
  requestedAtBlockNumber: number | bigint | string;
  requestedAtUnixMs: number | bigint | string;
  status: number | bigint | string;
  nonce: Bytes32;
  metadataHash: Bytes32;
}

export interface LocalBalanceRecordInput {
  accountId: Bytes32;
  assetId: Bytes32;
  availableAmount: number | bigint | string;
  lockedAmount: number | bigint | string;
  lastCreditId: Bytes32;
  lastWithdrawalId: Bytes32;
  stateRoot: Bytes32;
  updatedAtBlockNumber: number | bigint | string;
  nonce: Bytes32;
}

export interface ProductTransferInput {
  fromAccountId: Bytes32;
  toAccountId: Bytes32;
  assetId: Bytes32;
  amount: number | bigint | string;
  accountNonce: number | bigint | string;
  deadlineBlock: number | bigint | string;
  memoHash: Bytes32;
}

export interface ProductTokenLaunchInput {
  issuerAccountId: Bytes32;
  tokenId: Bytes32;
  symbolHash: Bytes32;
  nameHash: Bytes32;
  metadataHash: Bytes32;
  decimals: number | bigint | string;
  initialSupply: number | bigint | string;
  recipientAccountId: Bytes32;
  accountNonce: number | bigint | string;
  launchPolicyHash: Bytes32;
}

export interface ProductPoolCreateInput {
  creatorAccountId: Bytes32;
  poolId: Bytes32;
  baseAssetId: Bytes32;
  quoteAssetId: Bytes32;
  feeBps: number | bigint | string;
  tickSpacing: number | bigint | string;
  metadataHash: Bytes32;
  accountNonce: number | bigint | string;
}

export interface ProductAddLiquidityInput {
  providerAccountId: Bytes32;
  poolId: Bytes32;
  baseAmount: number | bigint | string;
  quoteAmount: number | bigint | string;
  minLiquidityTokens: number | bigint | string;
  deadlineBlock: number | bigint | string;
  accountNonce: number | bigint | string;
}

export interface ProductRemoveLiquidityInput {
  providerAccountId: Bytes32;
  poolId: Bytes32;
  liquidityTokens: number | bigint | string;
  minBaseAmount: number | bigint | string;
  minQuoteAmount: number | bigint | string;
  deadlineBlock: number | bigint | string;
  accountNonce: number | bigint | string;
}

export interface ProductSwapInput {
  traderAccountId: Bytes32;
  poolId: Bytes32;
  assetInId: Bytes32;
  assetOutId: Bytes32;
  amountIn: number | bigint | string;
  minAmountOut: number | bigint | string;
  deadlineBlock: number | bigint | string;
  accountNonce: number | bigint | string;
}

export interface ProductBridgeCreditAckInput {
  creditId: Bytes32;
  depositId: Bytes32;
  accountId: Bytes32;
  assetId: Bytes32;
  amount: number | bigint | string;
  acknowledgedAtBlockNumber: number | bigint | string;
  accountNonce: number | bigint | string;
}

export interface BridgeWithdrawalIntentInput {
  creditId: Bytes32;
  depositId: Bytes32;
  sourceChainId: number | bigint | string;
  destinationChainId: number | bigint | string;
  token: Address;
  amount: number | bigint | string;
  flowchainAccount: Bytes32;
  baseRecipient: Address;
  status: string;
  requestedAt: string;
  testMode: boolean;
  broadcast: boolean;
  releasePolicy: string;
  productionReady: boolean;
}

export interface PilotCapInput {
  capId: Bytes32;
  assetId: Bytes32;
  maxAmount: number | bigint | string;
  usedAmount: number | bigint | string;
  unit: string;
  windowStartsAtUnixMs: number | bigint | string;
  windowEndsAtUnixMs: number | bigint | string;
  realValuePilot: boolean;
  productionReady: boolean;
}

export interface PilotBridgeCreditAckInput {
  chainId: number | bigint | string;
  contractAddress: Address;
  operatorId: Bytes32;
  creditId: Bytes32;
  depositId: Bytes32;
  accountId: Bytes32;
  assetId: Bytes32;
  amount: number | bigint | string;
  acknowledgedAtBlockNumber: number | bigint | string;
  accountNonce: number | bigint | string;
  issuedAtUnixMs: number | bigint | string;
  expiresAtUnixMs: number | bigint | string;
  pilotCap: PilotCapInput;
}

export interface PilotWithdrawalIntentInput {
  sourceChainId: number | bigint | string;
  destinationChainId: number | bigint | string;
  contractAddress: Address;
  operatorId: Bytes32;
  creditId: Bytes32;
  depositId: Bytes32;
  token: Address;
  amount: number | bigint | string;
  flowchainAccount: Bytes32;
  baseRecipient: Address;
  status: string;
  requestedAt: string;
  accountNonce: number | bigint | string;
  issuedAtUnixMs: number | bigint | string;
  expiresAtUnixMs: number | bigint | string;
  pilotCap: PilotCapInput;
}

export interface PilotReleaseEvidenceInput {
  chainId: number | bigint | string;
  contractAddress: Address;
  operatorId: Bytes32;
  withdrawalIntentId: Bytes32;
  releaseTxHash: Bytes32;
  releaseLogIndex: number | bigint | string;
  token: Address;
  amount: number | bigint | string;
  recipient: Address;
  releasedAtBlockNumber: number | bigint | string;
  releasedAtUnixMs: number | bigint | string;
  evidenceHash: Bytes32;
  issuedAtUnixMs: number | bigint | string;
  expiresAtUnixMs: number | bigint | string;
  pilotCap: PilotCapInput;
}

export interface PilotEmergencyControlInput {
  chainId: number | bigint | string;
  contractAddress: Address;
  operatorId: Bytes32;
  action: string;
  targetSignerId: Bytes32;
  reasonHash: Bytes32;
  issuedAtUnixMs: number | bigint | string;
  expiresAtUnixMs: number | bigint | string;
  nonce: Bytes32;
  pilotCap: PilotCapInput;
}

export interface ControlPlaneProvenanceResponseInput {
  requestId: Bytes32;
  subjectId: Bytes32;
  agentId: Bytes32;
  receiptId: Bytes32;
  reportId: Bytes32;
  memoryCellId: Bytes32;
  dependencyRoot: Bytes32;
  responseBodyHash: Bytes32;
  issuedAtUnixMs: number | bigint | string;
  responseVersion: number | bigint | string;
}

export interface HardwareSignalEnvelopeInput {
  deviceId: Bytes32;
  signalRoot: Bytes32;
  previousSignalEnvelopeId: Bytes32;
  channelRoot: Bytes32;
  sequence: number | bigint | string;
  observedAtUnixMs: number | bigint | string;
  transport: number | bigint | string;
  nonce: Bytes32;
}

export interface LocalSignatureEnvelopeInput {
  objectId: Bytes32;
  objectTypeHash: Bytes32;
  domainSeparator: Bytes32;
  signerId: Bytes32;
  signerKeyId: Bytes32;
  signerRole: number | bigint | string;
  sequence: number | bigint | string;
  issuedAtUnixMs: number | bigint | string;
  expiresAtUnixMs: number | bigint | string;
  nonce: Bytes32;
}

export interface LocalSignatureEnvelopePayload {
  structHash: Bytes32;
  signingDigest: Bytes32;
}

export interface LocalTransactionEnvelopeInput {
  chainId: number | bigint | string;
  domainSeparator: Bytes32;
  signerId: Bytes32;
  signerKeyId: Bytes32;
  signerRole: number | bigint | string;
  nonce: number | bigint | string;
  payloadHash: Bytes32;
  objectId: Bytes32;
  objectTypeHash: Bytes32;
  issuedAtUnixMs: number | bigint | string;
}

export interface LocalTransactionEnvelopePayload {
  structHash: Bytes32;
  signingDigest: Bytes32;
}

export interface LocalAlphaEnvelopeValidationInput {
  document: Record<string, unknown>;
  envelope: Record<string, unknown>;
  context?: {
    seenSequences?: Set<string>;
  };
}

export interface LocalAlphaEnvelopeValidationResult {
  valid: boolean;
  errors: string[];
}

export interface WalletEnvelopeVerificationResult {
  schema: "flowchain.wallet_envelope_verification.v0";
  valid: boolean;
  signatureValid: boolean;
  chainIdMatch: boolean;
  signerDerivedAddress: Bytes32 | null;
  payloadHash: Bytes32 | null;
  transactionId: Bytes32 | null;
  replayKey: string | null;
  rejectionReason: string | null;
  errors: string[];
}

export const ZERO_BYTES32: Bytes32;
export const FLOWPULSE_SCHEMA_ID_PREIMAGE: string;
export const FLOWPULSE_EVENT_SIGNATURE: string;
export const TYPE_STRINGS: Readonly<Record<string, string>>;
export const DOMAIN_STRINGS: Readonly<Record<string, string>>;
export const MERKLE_SCHEME_V0: string;
export const VERIFIER_STATUSES: Readonly<Record<string, number>>;
export const LOCAL_ALPHA_OBJECT_STATUSES: Readonly<Record<string, number>>;
export const LOCAL_ALPHA_CHALLENGE_TYPES: Readonly<Record<string, number>>;
export const LOCAL_ALPHA_CHALLENGE_STATUSES: Readonly<Record<string, number>>;
export const LOCAL_ALPHA_FINALITY_STATES: Readonly<Record<string, number>>;
export const LOCAL_ALPHA_HARDWARE_TRANSPORTS: Readonly<Record<string, number>>;
export const LOCAL_ALPHA_SIGNER_ROLES: Readonly<Record<string, number>>;
export const LOCAL_ALPHA_BRIDGE_STATUSES: Readonly<Record<string, number>>;
export const FLOWCHAIN_ACCOUNT_ROLES: Readonly<Record<string, { code: number; roleGated: boolean; description: string }>>;
export const FLOWCHAIN_PUBLIC_KEY_ENCODING: string;
export const FLOWCHAIN_NETWORK_PROFILES: Readonly<Record<string, string>>;
export const FLOWCHAIN_DOMAIN_SEPARATORS: Readonly<Record<string, string>>;
export const LOCAL_WALLET_PUBLIC_METADATA_SCHEMA: string;
export const LOCAL_WALLET_KEY_SCHEME: string;
export const DEFAULT_LOCAL_WALLET_CHAIN_ID: string;
export const LOCAL_TEST_UNIT_ASSET_ID: Bytes32;
export const WALLET_SIGNED_ENVELOPE_SCHEMA: string;
export const WALLET_ENVELOPE_VERIFICATION_SCHEMA: string;

export function strip0x(value: string): string;
export function bytesToHex(bytes: Uint8Array): Hex;
export function hexToBytes(value: Hex | string, expectedLength?: number): Uint8Array;
export function normalizeHex(value: Hex | string, expectedLength?: number): Hex;
export function utf8Bytes(value: unknown): Uint8Array;
export function concatBytes(...parts: Uint8Array[]): Uint8Array;
export function uintToWord(value: number | bigint | string): Uint8Array;
export function uintBe(value: number | bigint | string, byteLength: number): Uint8Array;
export function addressToWord(value: Address): Uint8Array;
export function bytes32ToWord(value: Bytes32): Uint8Array;
export function abiEncodeStatic(fields: Array<[string, unknown]>): Uint8Array;
export function canonicalJson(value: unknown): string;

export function keccak256Bytes(data: Uint8Array): Uint8Array;
export function keccak256Hex(data: Uint8Array): Hex;
export function keccakUtf8(value: unknown): Bytes32;
export function canonicalJsonHash(value: unknown): Bytes32;
export function typeHash(typeString: string): Bytes32;
export function typedHash(typeString: string, fields: Array<[string, unknown]>): Bytes32;
export function domainSeparatedHash(domain: string, payloadBytes: Uint8Array): Bytes32;
export function domainSeparator(domainName: string): Bytes32;
export function normalizeFlowchainPublicKey(publicKey: Hex | string): Hex;
export function flowchainPublicKeyHash(publicKey: Hex | string): Bytes32;
export function flowchainAddressFromPublicKey(publicKey: Hex | string): Address;
export function flowchainRoleMetadata(role: string): Record<string, unknown>;
export function flowchainRoleRoot(role: string): Bytes32;
export function flowchainAccountId(input: { publicKey: Hex | string; role?: string }): Bytes32;
export function flowchainSignerKeyId(input: { publicKey: Hex | string }): Bytes32;
export function flowchainPublicAccountMetadata(input: {
  publicKey: Hex | string;
  role?: string;
  label?: string;
  createdAtUnixMs?: number | bigint | string;
  active?: boolean;
}): Record<string, unknown>;
export function assertFlowchainPublicMetadataContainsNoSecrets(value: unknown): void;
export function isFlowchainRole(role: string): boolean;

export function flowPulseSchemaId(): Bytes32;
export function flowPulseEventSignature(): Bytes32;
export function contractPulseId(input: FlowPulseContractInput): Bytes32;
export function flowPulseObservationId(input: FlowPulseObservationInput): Bytes32;
export function flowPulseEventArgsHash(input: FlowPulseEventArgsInput): Bytes32;
export function receiptHash(input: ReceiptInput): Bytes32;
export function verifierReportHash(input: VerifierReportInput): Bytes32;
export const reportDigest: typeof verifierReportHash;
export function eip712Digest(domainSeparator: Bytes32, structHash: Bytes32): Bytes32;

export function chunkHash(chunk: string | Uint8Array): Bytes32;
export function merkleLeafHash(input: MerkleLeafInput): Bytes32;
export function merkleNodeHash(leftHash: Bytes32, rightHash: Bytes32): Bytes32;
export function emptyMerkleRoot(): Bytes32;
export function merkleRoot(leafHashes: Bytes32[]): Bytes32;
export function buildArtifactManifest(input: { chunks: Array<string | Uint8Array>; chunkSize: number | bigint | string }): unknown;
export function artifactCommitmentHash(input: {
  schemeId: Bytes32;
  manifestHash: Bytes32;
  contentMerkleRoot: Bytes32;
  byteLength: number | bigint | string;
  chunkSize: number | bigint | string;
  mediaTypeHash: Bytes32;
  metadataHash: Bytes32;
}): Bytes32;
export const artifactCommitment: typeof artifactCommitmentHash;
export function artifactFromChunks(input: ArtifactInput): ArtifactOutput;
export function storageReceiptCommitmentHash(input: StorageReceiptCommitmentInput): Bytes32;

export function eip712DomainSeparator(input: {
  nameHash: Bytes32;
  versionHash: Bytes32;
  chainId: number | bigint | string;
  verifyingContract: Address;
  salt: Bytes32;
}): Bytes32;
export function workerSignatureStructHash(input: WorkerSignatureInput): Bytes32;
export function verifierSignatureStructHash(input: VerifierSignatureInput): Bytes32;
export function attestationEnvelopeHash(input: AttestationEnvelopeInput): Bytes32;
export const attestationDigest: typeof attestationEnvelopeHash;
export function workerSignaturePayload(input: SignatureDomainInput & WorkerSignatureInput): { structHash: Bytes32; signingDigest: Bytes32 };
export function verifierSignaturePayload(input: SignatureDomainInput & VerifierSignatureInput): { structHash: Bytes32; signingDigest: Bytes32 };
export function publicKeyFromPrivateKey(privateKeyHex: Hex): Hex;
export function signDigest(input: { digest: Bytes32; privateKey: Hex }): Promise<Hex>;
export function verifyDigest(input: { digest: Bytes32; signature: Hex; publicKey: Hex }): boolean;

export function indexerCursorId(input: IndexerCursorInput): Bytes32;
export const cursorId: typeof indexerCursorId;
export function rootfieldNamespaceId(input: RootfieldNamespaceInput): Bytes32;
export function rootCommitment(input: RootCommitmentInput): Bytes32;
export function workReceiptId(input: WorkReceiptInput): Bytes32;
export function workerIdentity(input: WorkerIdentityInput): Bytes32;
export function verifierIdentity(input: VerifierIdentityInput): Bytes32;
export function devnetBlockHash(input: DevnetBlockInput): Bytes32;
export function agentAccountId(input: AgentAccountInput): Bytes32;
export function modelPassportId(input: ModelPassportInput): Bytes32;
export function memoryCellId(input: MemoryCellInput): Bytes32;
export function artifactAvailabilityProofId(input: ArtifactAvailabilityProofInput): Bytes32;
export function verifierModuleId(input: VerifierModuleInput): Bytes32;
export function challengeId(input: ChallengeInput): Bytes32;
export function finalityReceiptId(input: FinalityReceiptInput): Bytes32;
export function bridgeDepositId(input: BridgeDepositInput): Bytes32;
export function bridgeCreditId(input: BridgeCreditInput): Bytes32;
export function bridgeWithdrawalId(input: BridgeWithdrawalInput): Bytes32;
export function localBalanceRecordId(input: LocalBalanceRecordInput): Bytes32;
export function productTransferId(input: ProductTransferInput): Bytes32;
export function productTokenLaunchId(input: ProductTokenLaunchInput): Bytes32;
export function productPoolCreateId(input: ProductPoolCreateInput): Bytes32;
export function productAddLiquidityId(input: ProductAddLiquidityInput): Bytes32;
export function productRemoveLiquidityId(input: ProductRemoveLiquidityInput): Bytes32;
export function productSwapId(input: ProductSwapInput): Bytes32;
export function productBridgeCreditAckId(input: ProductBridgeCreditAckInput): Bytes32;
export function bridgeWithdrawalIntentId(input: BridgeWithdrawalIntentInput): Bytes32;
export function flowchainNetworkProfileHash(networkProfile: string): Bytes32;
export function flowchainProductionDomain(input: { chainId: number | bigint | string; networkProfile: string }): string;
export function flowchainProductionDomainSeparator(input: { chainId: number | bigint | string; networkProfile: string }): Bytes32;
export function flowchainTransactionId(envelope: Record<string, unknown>): Bytes32;
export function flowchainTxRoot(transactions: unknown[]): Bytes32;
export function flowchainReceiptRoot(receipts: unknown[]): Bytes32;
export function flowchainEventRoot(events: unknown[]): Bytes32;
export function flowchainAccountStateRoot(accounts: unknown[]): Bytes32;
export function flowchainTokenStateRoot(tokens: unknown[]): Bytes32;
export function flowchainDexStateRoot(pools: unknown[]): Bytes32;
export function flowchainBlockHash(input: Record<string, unknown>): Bytes32;
export function flowchainBridgeObservationId(input: Record<string, unknown>): Bytes32;
export function flowchainBridgeSourceEventReplayKey(input: Record<string, unknown>): Bytes32;
export function flowchainBridgeEvidenceHash(input: Record<string, unknown>): Bytes32;
export function flowchainBridgeCreditId(input: Record<string, unknown>): Bytes32;
export function flowchainWithdrawalIntentId(input: Record<string, unknown>): Bytes32;
export function flowchainFinalityReceiptId(input: Record<string, unknown>): Bytes32;
export function accountNonceReplayKey(input: Record<string, unknown>): Bytes32;
export function roleScopedNonceReplayKey(input: Record<string, unknown>): Bytes32;
export function bridgeSourceEventReplayKey(input: Record<string, unknown>): Bytes32;
export function withdrawalIntentReplayKey(input: Record<string, unknown>): Bytes32;
export function finalityVoteReplayKey(input: Record<string, unknown>): Bytes32;
export function pilotCapHash(input: PilotCapInput): Bytes32;
export function pilotBridgeCreditAckId(input: PilotBridgeCreditAckInput): Bytes32;
export function pilotWithdrawalIntentId(input: PilotWithdrawalIntentInput): Bytes32;
export function pilotReleaseEvidenceId(input: PilotReleaseEvidenceInput): Bytes32;
export function pilotEmergencyControlId(input: PilotEmergencyControlInput): Bytes32;
export function hardwareSignalEnvelopeId(input: HardwareSignalEnvelopeInput): Bytes32;
export function controlPlaneProvenanceResponseId(input: ControlPlaneProvenanceResponseInput): Bytes32;
export function localSignatureEnvelopeHash(input: LocalSignatureEnvelopeInput): Bytes32;
export const localSignatureEnvelopeId: typeof localSignatureEnvelopeHash;
export function localSignatureEnvelopePayload(input: LocalSignatureEnvelopeInput): LocalSignatureEnvelopePayload;
export function localAlphaObjectTypeHash(objectSchema: string): Bytes32;
export const LOCAL_ALPHA_OBJECT_DESCRIPTORS: Readonly<Record<string, unknown>>;
export function localAlphaObjectDescriptor(objectSchema: string): unknown;
export function localAlphaObjectInput(document: Record<string, unknown>): unknown;
export function localAlphaObjectId(document: Record<string, unknown>): Bytes32;
export function localAlphaEnvelopeReplayKey(envelope: Record<string, unknown>): string;
export function localSignatureEnvelopeInput(envelope: Record<string, unknown>): LocalSignatureEnvelopeInput;
export function validateLocalAlphaEnvelope(
  input: LocalAlphaEnvelopeValidationInput
): LocalAlphaEnvelopeValidationResult;

export function localTransactionEnvelopeHash(input: LocalTransactionEnvelopeInput): Bytes32;
export const localTransactionEnvelopeId: typeof localTransactionEnvelopeHash;
export function localTransactionEnvelopePayload(input: LocalTransactionEnvelopeInput): LocalTransactionEnvelopePayload;
export function localTransactionEnvelopeInput(envelope: Record<string, unknown>): LocalTransactionEnvelopeInput;
export function localTransactionReplayKey(envelope: Record<string, unknown>): string;
export function localTransactionDomain(chainId: number | bigint | string): string;
export function localTransactionDomainSeparator(chainId: number | bigint | string): Bytes32;
export function buildUnsignedLocalTransactionEnvelope(input: {
  document: Record<string, unknown>;
  chainId: number | bigint | string;
  nonce: number | bigint | string;
  signerId: Bytes32;
  signerKeyId: Bytes32;
  signerRole: string;
  publicKey: Hex;
  issuedAtUnixMs: number | bigint | string;
}): Record<string, unknown>;
export function validateLocalTransactionEnvelope(input: {
  document: Record<string, unknown>;
  envelope: Record<string, unknown>;
  context?: {
    chainId?: number | bigint | string;
    expectedNonce?: number | bigint | string;
    expectedSignerId?: Bytes32;
    seenNonces?: Set<string>;
  };
}): LocalAlphaEnvelopeValidationResult;

export function createEncryptedTestVault(input?: {
  password: string;
  label?: string;
  signerRole?: string;
  createdAtUnixMs?: number | bigint | string;
  privateKey?: Hex;
  chainId?: number | bigint | string;
  lastKnownNonce?: number | bigint | string;
}): Record<string, unknown>;
export function unlockEncryptedTestVault(input: {
  vault: Record<string, unknown>;
  password: string;
}): Record<string, unknown>;
export function listVaultPublicAccounts(vaultOrSession: Record<string, unknown>): Array<Record<string, unknown>>;
export function exportVaultPublicMetadata(vaultOrSession: Record<string, unknown>): Record<string, unknown>;
export function exportLocalWalletPublicMetadata(
  vaultOrSession: Record<string, unknown>,
  input?: { updatedAtUnixMs?: number | bigint | string }
): Record<string, unknown>;
export function validateLocalWalletPublicMetadata(
  metadata: Record<string, unknown>,
  context?: { expectedChainId?: number | bigint | string }
): {
  schema: string;
  valid: boolean;
  secretFree: boolean;
  chainIdMatch: boolean;
  accountCount: number;
  errors: string[];
};
export function addEncryptedTestVaultAccount(input: {
  vault: Record<string, unknown>;
  password: string;
  label?: string;
  signerRole?: string;
  createdAtUnixMs?: number | bigint | string;
  privateKey?: Hex;
  signerId?: Bytes32;
  chainId?: number | bigint | string;
  lastKnownNonce?: number | bigint | string;
}): Record<string, unknown>;
export function rotateEncryptedTestVaultAccount(input: {
  vault: Record<string, unknown>;
  password: string;
  signerKeyId: Bytes32;
  label?: string;
  createdAtUnixMs?: number | bigint | string;
  privateKey?: Hex;
  chainId?: number | bigint | string;
}): Record<string, unknown>;
export function signLocalTransactionWithVault(input: {
  vault: Record<string, unknown>;
  password: string;
  signerKeyId: Bytes32;
  document: Record<string, unknown>;
  chainId: number | bigint | string;
  nonce: number | bigint | string;
  issuedAtUnixMs?: number | bigint | string;
}): Promise<Record<string, unknown>>;
export function verifyLocalTransactionSignature(input: {
  document: Record<string, unknown>;
  envelope: Record<string, unknown>;
  context?: Record<string, unknown>;
}): LocalAlphaEnvelopeValidationResult;
export function verifyFlowchainEnvelope(input: {
  document: Record<string, unknown>;
  envelope: Record<string, unknown>;
  context?: Record<string, unknown>;
}): Record<string, unknown>;

export function buildProductTransferDocument(input: Record<string, unknown>): Record<string, unknown>;
export function buildProductTokenLaunchDocument(input: Record<string, unknown>): Record<string, unknown>;
export function buildProductPoolCreateDocument(input: Record<string, unknown>): Record<string, unknown>;
export function buildProductAddLiquidityDocument(input: Record<string, unknown>): Record<string, unknown>;
export function buildProductRemoveLiquidityDocument(input: Record<string, unknown>): Record<string, unknown>;
export function buildProductSwapDocument(input: Record<string, unknown>): Record<string, unknown>;
export function buildBridgeWithdrawalIntentDocument(input: Record<string, unknown>): Record<string, unknown>;
export function buildFinalityActionDocument(input: Record<string, unknown>): Record<string, unknown>;
export function signWalletDocumentWithVault(input: {
  vault: Record<string, unknown>;
  password: string;
  signerKeyId: Bytes32;
  document: Record<string, unknown>;
  chainId: number | bigint | string;
  nonce: number | bigint | string;
  issuedAtUnixMs?: number | bigint | string;
  fee?: Record<string, unknown> | null;
  expiresAtUnixMs?: number | bigint | string | null;
}): Promise<Record<string, unknown>>;
export function verifyWalletSignedEnvelope(input: {
  envelope: Record<string, unknown>;
  context?: {
    document?: Record<string, unknown>;
    chainId?: number | bigint | string;
    expectedNonce?: number | bigint | string;
    expectedSignerId?: Bytes32;
    expectedSignerAddress?: Bytes32;
    expectedPayloadType?: string;
    seenNonces?: Set<string>;
  };
}): WalletEnvelopeVerificationResult;

export const PILOT_MESSAGE_SCHEMAS: readonly string[];
export function validatePilotOperatorEnvelope(input: {
  document: Record<string, unknown>;
  envelope: Record<string, unknown>;
  context?: {
    chainId?: number | bigint | string;
    expectedChainId?: number | bigint | string;
    expectedDestinationChainId?: number | bigint | string;
    expectedContractAddress?: string;
    expectedOperatorId?: Bytes32;
    expectedNonce?: number | bigint | string;
    expectedSignerId?: Bytes32;
    seenNonces?: Set<string>;
    nowUnixMs?: number | bigint | string;
  };
}): LocalAlphaEnvelopeValidationResult;
export function pilotEnvelopeReplayKey(envelope: Record<string, unknown>): string;
export function assertPublicPilotMetadataContainsNoSecrets(value: unknown): void;
export function createPilotOperatorConfigFromEnv(input?: {
  env?: Record<string, string | undefined>;
  createdAtUnixMs?: number | bigint | string;
}): Record<string, unknown>;
export function buildPilotNextCommands(config: Record<string, unknown>): string[];
export function exportPilotPublicMetadata(input: {
  config: Record<string, unknown>;
  walletMetadata: Record<string, unknown>;
}): Record<string, unknown>;
export function buildPilotBridgeCreditAckDocument(input: PilotBridgeCreditAckInput): Record<string, unknown>;
export function buildPilotWithdrawalIntentDocument(input: PilotWithdrawalIntentInput): Record<string, unknown>;
export function buildPilotReleaseEvidenceDocument(input: PilotReleaseEvidenceInput): Record<string, unknown>;
export function buildPilotEmergencyControlDocument(input: PilotEmergencyControlInput): Record<string, unknown>;
