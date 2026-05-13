import { TYPE_STRINGS } from "./constants.js";
import { hexToBytes, bytesToHex } from "./encoding.js";
import { typedHash } from "./hashes.js";
import { eip712Digest } from "./flowpulse.js";
import * as secp from "@noble/secp256k1";
import { hmac } from "@noble/hashes/hmac.js";
import { sha256 } from "@noble/hashes/sha2.js";

secp.hashes.sha256 = sha256;
secp.hashes.hmacSha256 = (key, ...messages) => hmac(sha256, key, secp.etc.concatBytes(...messages));

export function eip712DomainSeparator({ nameHash, versionHash, chainId, verifyingContract, salt }) {
  return typedHash(TYPE_STRINGS.eip712Domain, [
    ["bytes32", nameHash],
    ["bytes32", versionHash],
    ["uint256", chainId],
    ["address", verifyingContract],
    ["bytes32", salt]
  ]);
}

export function workerSignatureStructHash({
  receiptHash,
  workerId,
  workerKeyId,
  workerSequence,
  expiresAtUnixMs,
  artifactRoot,
  nonce
}) {
  return typedHash(TYPE_STRINGS.workerSignatureV0, [
    ["bytes32", receiptHash],
    ["bytes32", workerId],
    ["bytes32", workerKeyId],
    ["uint64", workerSequence],
    ["uint64", expiresAtUnixMs],
    ["bytes32", artifactRoot],
    ["bytes32", nonce]
  ]);
}

export function verifierSignatureStructHash({
  reportId,
  verifierId,
  verifierKeyId,
  verifierSetRoot,
  issuedAtUnixMs,
  expiresAtUnixMs,
  nonce
}) {
  return typedHash(TYPE_STRINGS.verifierSignatureV0, [
    ["bytes32", reportId],
    ["bytes32", verifierId],
    ["bytes32", verifierKeyId],
    ["bytes32", verifierSetRoot],
    ["uint64", issuedAtUnixMs],
    ["uint64", expiresAtUnixMs],
    ["bytes32", nonce]
  ]);
}

export function attestationEnvelopeHash({
  subjectHash,
  subjectKind,
  attesterId,
  attesterKeyId,
  verifierSetRoot,
  issuedAtUnixMs,
  expiresAtUnixMs,
  nonce
}) {
  return typedHash(TYPE_STRINGS.attestationEnvelopeV0, [
    ["bytes32", subjectHash],
    ["uint8", subjectKind],
    ["bytes32", attesterId],
    ["bytes32", attesterKeyId],
    ["bytes32", verifierSetRoot],
    ["uint64", issuedAtUnixMs],
    ["uint64", expiresAtUnixMs],
    ["bytes32", nonce]
  ]);
}

export const attestationDigest = attestationEnvelopeHash;

export function workerSignaturePayload({ domainSeparator, ...payload }) {
  const structHash = workerSignatureStructHash(payload);
  return {
    structHash,
    signingDigest: eip712Digest(domainSeparator, structHash)
  };
}

export function verifierSignaturePayload({ domainSeparator, ...payload }) {
  const structHash = verifierSignatureStructHash(payload);
  return {
    structHash,
    signingDigest: eip712Digest(domainSeparator, structHash)
  };
}

export function publicKeyFromPrivateKey(privateKeyHex) {
  return bytesToHex(secp.getPublicKey(hexToBytes(privateKeyHex, 32)));
}

export async function signDigest({ digest, privateKey }) {
  const signature = await secp.sign(hexToBytes(digest, 32), hexToBytes(privateKey, 32), {
    prehash: false
  });
  return bytesToHex(signature);
}

export function verifyDigest({ digest, signature, publicKey }) {
  return secp.verify(hexToBytes(signature, 64), hexToBytes(digest, 32), hexToBytes(publicKey), {
    prehash: false
  });
}
