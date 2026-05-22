import * as secp from "@noble/secp256k1";

import { FLOWMEMORY_ACCOUNT_ROLES, TYPE_STRINGS } from "./constants.js";
import { hexToBytes, strip0x } from "./encoding.js";
import { canonicalJsonHash, keccak256Hex, typedHash } from "./hashes.js";

export const FLOWMEMORY_PUBLIC_KEY_ENCODING = "secp256k1-compressed-hex";

export function normalizeFlowMemoryPublicKey(publicKey) {
  const raw = hexToBytes(publicKey);
  if (![33, 65].includes(raw.length)) {
    throw new Error("malformed public key");
  }
  const point = secp.Point.fromHex(strip0x(publicKey));
  point.assertValidity();
  return `0x${point.toHex(true)}`;
}

export function flowmemoryPublicKeyHash(publicKey) {
  return canonicalJsonHash({
    schema: "flowmemory.public_key.v0",
    encoding: FLOWMEMORY_PUBLIC_KEY_ENCODING,
    publicKey: normalizeFlowMemoryPublicKey(publicKey)
  });
}

export function flowmemoryAddressFromPublicKey(publicKey) {
  const publicKeyHash = flowmemoryPublicKeyHash(publicKey);
  const digest = keccak256Hex(hexToBytes(publicKeyHash, 32));
  return `0x${strip0x(digest).slice(-40)}`;
}

export function flowmemoryRoleMetadata(role) {
  const metadata = FLOWMEMORY_ACCOUNT_ROLES[role];
  if (!metadata) {
    throw new Error(`unsupported FlowMemory account role: ${role}`);
  }
  return {
    schema: "flowmemory.account_role_metadata.v0",
    role,
    roleCode: metadata.code,
    roleGated: metadata.roleGated,
    description: metadata.description
  };
}

export function flowmemoryRoleRoot(role) {
  return canonicalJsonHash(flowmemoryRoleMetadata(role));
}

export function flowmemoryAccountId({ publicKey, role = "user" }) {
  const normalizedPublicKey = normalizeFlowMemoryPublicKey(publicKey);
  return typedHash(TYPE_STRINGS.flowmemoryAccountIdV0, [
    ["bytes32", flowmemoryPublicKeyHash(normalizedPublicKey)],
    ["address", flowmemoryAddressFromPublicKey(normalizedPublicKey)],
    ["bytes32", flowmemoryRoleRoot(role)]
  ]);
}

export function flowmemorySignerKeyId({ publicKey }) {
  return canonicalJsonHash({
    schema: "flowmemory.signer_key.v0",
    publicKeyEncoding: FLOWMEMORY_PUBLIC_KEY_ENCODING,
    publicKey: normalizeFlowMemoryPublicKey(publicKey)
  });
}

export function flowmemoryPublicAccountMetadata({ publicKey, role = "user", label, createdAtUnixMs, active = true }) {
  const normalizedPublicKey = normalizeFlowMemoryPublicKey(publicKey);
  const roleMetadata = flowmemoryRoleMetadata(role);
  return {
    schema: "flowmemory.public_account_metadata.v0",
    label,
    role,
    roleCode: roleMetadata.roleCode,
    roleGated: roleMetadata.roleGated,
    publicKeyEncoding: FLOWMEMORY_PUBLIC_KEY_ENCODING,
    publicKey: normalizedPublicKey,
    publicKeyHash: flowmemoryPublicKeyHash(normalizedPublicKey),
    address: flowmemoryAddressFromPublicKey(normalizedPublicKey),
    accountId: flowmemoryAccountId({ publicKey: normalizedPublicKey, role }),
    signerKeyId: flowmemorySignerKeyId({ publicKey: normalizedPublicKey }),
    createdAtUnixMs,
    active
  };
}

export function assertFlowMemoryPublicMetadataContainsNoSecrets(value) {
  const serialized = JSON.stringify(value);
  if (
    /privateKey|private_key|seedPhrase|seed phrase|mnemonic|ciphertext|authTag|password|rpc[-_]?credential|rpc[-_]?url|api[-_]?key|webhook/i.test(serialized) ||
    /https:\/\/hooks\.slack\.com|https:\/\/discord\.com\/api\/webhooks/i.test(serialized)
  ) {
    throw new Error("public FlowMemory metadata contains secret-shaped material");
  }
}

export function isFlowMemoryRole(role) {
  return Boolean(FLOWMEMORY_ACCOUNT_ROLES[role]);
}
