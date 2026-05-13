import { MERKLE_SCHEME_V0, TYPE_STRINGS } from "./constants.js";
import { abiEncodeStatic, canonicalJson, utf8Bytes } from "./encoding.js";
import { keccak256Hex, keccakUtf8, typedHash } from "./hashes.js";

export function chunkHash(chunk) {
  const bytes = typeof chunk === "string" ? utf8Bytes(chunk) : chunk;
  return keccak256Hex(bytes);
}

export function merkleLeafHash({ index, offset, length, chunkHash: chunkHashHex }) {
  return typedHash(TYPE_STRINGS.merkleLeafV0, [
    ["uint64", index],
    ["uint64", offset],
    ["uint32", length],
    ["bytes32", chunkHashHex]
  ]);
}

export function merkleNodeHash(leftHash, rightHash) {
  return typedHash(TYPE_STRINGS.merkleInternalNodeV0, [
    ["bytes32", leftHash],
    ["bytes32", rightHash]
  ]);
}

export function emptyMerkleRoot() {
  return keccakUtf8(`${MERKLE_SCHEME_V0}:EMPTY`);
}

export function merkleRoot(leafHashes) {
  if (leafHashes.length === 0) {
    return emptyMerkleRoot();
  }
  let level = [...leafHashes];
  while (level.length > 1) {
    const next = [];
    for (let i = 0; i < level.length; i += 2) {
      if (i + 1 < level.length) {
        next.push(merkleNodeHash(level[i], level[i + 1]));
      } else {
        next.push(level[i]);
      }
    }
    level = next;
  }
  return level[0];
}

export function buildArtifactManifest({ chunks, chunkSize }) {
  let offset = 0;
  const manifestChunks = chunks.map((chunk, index) => {
    const data = typeof chunk === "string" ? utf8Bytes(chunk) : chunk;
    const entry = {
      index,
      offset,
      length: data.length,
      chunkHash: keccak256Hex(data)
    };
    offset += data.length;
    return entry;
  });
  return {
    scheme: MERKLE_SCHEME_V0,
    version: 0,
    chunkSize,
    byteLength: offset,
    chunks: manifestChunks
  };
}

export function artifactCommitmentHash({
  schemeId,
  manifestHash,
  contentMerkleRoot,
  byteLength,
  chunkSize,
  mediaTypeHash,
  metadataHash
}) {
  return typedHash(TYPE_STRINGS.artifactRootV0, [
    ["bytes32", schemeId],
    ["bytes32", manifestHash],
    ["bytes32", contentMerkleRoot],
    ["uint64", byteLength],
    ["uint32", chunkSize],
    ["bytes32", mediaTypeHash],
    ["bytes32", metadataHash]
  ]);
}

export const artifactCommitment = artifactCommitmentHash;

export function artifactFromChunks({ chunks, chunkSize, mediaType, metadata }) {
  const manifest = buildArtifactManifest({ chunks, chunkSize });
  const leafHashes = manifest.chunks.map((entry) => merkleLeafHash(entry));
  const contentMerkleRoot = merkleRoot(leafHashes);
  const manifestHash = keccak256Hex(utf8Bytes(canonicalJson(manifest)));
  const metadataHash = keccak256Hex(utf8Bytes(canonicalJson(metadata)));
  const mediaTypeHash = keccakUtf8(mediaType);
  const schemeId = keccakUtf8(MERKLE_SCHEME_V0);
  const artifactRoot = artifactCommitmentHash({
    schemeId,
    manifestHash,
    contentMerkleRoot,
    byteLength: manifest.byteLength,
    chunkSize,
    mediaTypeHash,
    metadataHash
  });

  return {
    schemeId,
    manifest,
    manifestHash,
    leafHashes,
    contentMerkleRoot,
    metadataHash,
    mediaTypeHash,
    artifactRoot
  };
}

export function storageReceiptCommitmentHash({
  artifactRoot,
  providerId,
  locationCommitment,
  retentionPolicyHash,
  encryptionCommitment,
  availabilitySampleRoot,
  issuedAtUnixMs,
  expiresAtUnixMs,
  nonce
}) {
  return keccak256Hex(
    abiEncodeStatic([
      ["bytes32", keccakUtf8(TYPE_STRINGS.storageReceiptCommitmentV0)],
      ["bytes32", artifactRoot],
      ["bytes32", providerId],
      ["bytes32", locationCommitment],
      ["bytes32", retentionPolicyHash],
      ["bytes32", encryptionCommitment],
      ["bytes32", availabilitySampleRoot],
      ["uint64", issuedAtUnixMs],
      ["uint64", expiresAtUnixMs],
      ["bytes32", nonce]
    ])
  );
}
