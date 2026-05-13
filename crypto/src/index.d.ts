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

export const ZERO_BYTES32: Bytes32;
export const FLOWPULSE_SCHEMA_ID_PREIMAGE: string;
export const FLOWPULSE_EVENT_SIGNATURE: string;
export const TYPE_STRINGS: Readonly<Record<string, string>>;
export const DOMAIN_STRINGS: Readonly<Record<string, string>>;
export const MERKLE_SCHEME_V0: string;
export const VERIFIER_STATUSES: Readonly<Record<string, number>>;

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
