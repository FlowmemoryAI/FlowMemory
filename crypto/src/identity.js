import * as secp from "@noble/secp256k1";

import { FLOWCHAIN_ACCOUNT_ROLES, TYPE_STRINGS } from "./constants.js";
import { hexToBytes, strip0x } from "./encoding.js";
import { canonicalJsonHash, keccak256Hex, typedHash } from "./hashes.js";

export const FLOWCHAIN_PUBLIC_KEY_ENCODING = "secp256k1-compressed-hex";

export function normalizeFlowchainPublicKey(publicKey) {
  const raw = hexToBytes(publicKey);
  if (![33, 65].includes(raw.length)) {
    throw new Error("malformed public key");
  }
  const point = secp.Point.fromHex(strip0x(publicKey));
  point.assertValidity();
  return `0x${point.toHex(true)}`;
}

export function flowchainPublicKeyHash(publicKey) {
  return canonicalJsonHash({
    schema: "flowchain.public_key.v0",
    encoding: FLOWCHAIN_PUBLIC_KEY_ENCODING,
    publicKey: normalizeFlowchainPublicKey(publicKey)
  });
}

export function flowchainAddressFromPublicKey(publicKey) {
  const publicKeyHash = flowchainPublicKeyHash(publicKey);
  const digest = keccak256Hex(hexToBytes(publicKeyHash, 32));
  return `0x${strip0x(digest).slice(-40)}`;
}

export function flowchainRoleMetadata(role) {
  const metadata = FLOWCHAIN_ACCOUNT_ROLES[role];
  if (!metadata) {
    throw new Error(`unsupported FlowChain account role: ${role}`);
  }
  return {
    schema: "flowchain.account_role_metadata.v0",
    role,
    roleCode: metadata.code,
    roleGated: metadata.roleGated,
    description: metadata.description
  };
}

export function flowchainRoleRoot(role) {
  return canonicalJsonHash(flowchainRoleMetadata(role));
}

export function flowchainAccountId({ publicKey, role = "user" }) {
  const normalizedPublicKey = normalizeFlowchainPublicKey(publicKey);
  return typedHash(TYPE_STRINGS.flowchainAccountIdV0, [
    ["bytes32", flowchainPublicKeyHash(normalizedPublicKey)],
    ["address", flowchainAddressFromPublicKey(normalizedPublicKey)],
    ["bytes32", flowchainRoleRoot(role)]
  ]);
}

export function flowchainSignerKeyId({ publicKey }) {
  return canonicalJsonHash({
    schema: "flowchain.signer_key.v0",
    publicKeyEncoding: FLOWCHAIN_PUBLIC_KEY_ENCODING,
    publicKey: normalizeFlowchainPublicKey(publicKey)
  });
}

export function flowchainPublicAccountMetadata({ publicKey, role = "user", label, createdAtUnixMs, active = true }) {
  const normalizedPublicKey = normalizeFlowchainPublicKey(publicKey);
  const roleMetadata = flowchainRoleMetadata(role);
  return {
    schema: "flowchain.public_account_metadata.v0",
    label,
    role,
    roleCode: roleMetadata.roleCode,
    roleGated: roleMetadata.roleGated,
    publicKeyEncoding: FLOWCHAIN_PUBLIC_KEY_ENCODING,
    publicKey: normalizedPublicKey,
    publicKeyHash: flowchainPublicKeyHash(normalizedPublicKey),
    address: flowchainAddressFromPublicKey(normalizedPublicKey),
    accountId: flowchainAccountId({ publicKey: normalizedPublicKey, role }),
    signerKeyId: flowchainSignerKeyId({ publicKey: normalizedPublicKey }),
    createdAtUnixMs,
    active
  };
}

export function assertFlowchainPublicMetadataContainsNoSecrets(value) {
  const serialized = JSON.stringify(value);
  if (
    /privateKey|private_key|seedPhrase|seed phrase|mnemonic|ciphertext|authTag|password|rpc[-_]?credential|rpc[-_]?url|api[-_]?key|webhook/i.test(serialized) ||
    /https:\/\/hooks\.slack\.com|https:\/\/discord\.com\/api\/webhooks/i.test(serialized)
  ) {
    throw new Error("public FlowChain metadata contains secret-shaped material");
  }
}

export function isFlowchainRole(role) {
  return Boolean(FLOWCHAIN_ACCOUNT_ROLES[role]);
}
