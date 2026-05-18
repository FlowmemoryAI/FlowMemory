import { createCipheriv, createDecipheriv, randomBytes, scryptSync } from "node:crypto";

import { bytesToHex } from "./encoding.js";
import { keccakUtf8 } from "./hashes.js";
import { publicKeyFromPrivateKey, signDigest } from "./attestations.js";
import {
  buildUnsignedLocalTransactionEnvelope,
  validateLocalTransactionEnvelope
} from "./transactions.js";
import { LOCAL_ALPHA_SIGNER_ROLES } from "./constants.js";

const VAULT_SCHEMA = "flowmemory.crypto.local-test-vault.v0";
const VAULT_SECRETS_SCHEMA = "flowmemory.crypto.local-test-vault-secrets.v0";
const PUBLIC_EXPORT_SCHEMA = "flowmemory.crypto.local-test-vault-public-metadata.v0";
export const LOCAL_WALLET_PUBLIC_METADATA_SCHEMA = "flowchain.local_wallet_public_metadata.v0";
export const LOCAL_WALLET_KEY_SCHEME = "secp256k1";
export const DEFAULT_LOCAL_WALLET_CHAIN_ID = "31337";

export function createEncryptedTestVault({
  password,
  label = "local-operator",
  signerRole = "operator",
  createdAtUnixMs = Date.now().toString(),
  privateKey,
  chainId = DEFAULT_LOCAL_WALLET_CHAIN_ID,
  lastKnownNonce = "0"
} = {}) {
  requirePassword(password);
  const account = createVaultAccount({ label, signerRole, createdAtUnixMs, privateKey, chainId, lastKnownNonce });
  return encryptVaultSecrets({
    password,
    publicAccounts: [publicAccount(account)],
    secrets: {
      schema: VAULT_SECRETS_SCHEMA,
      accounts: [account]
    },
    createdAtUnixMs
  });
}

export function unlockEncryptedTestVault({ vault, password }) {
  requirePassword(password);
  const secrets = decryptVaultSecrets({ vault, password });
  return {
    schema: "flowmemory.crypto.local-test-vault-session.v0",
    vaultId: vault.vaultId,
    createdAtUnixMs: vault.createdAtUnixMs,
    publicAccounts: vault.publicAccounts,
    accounts: secrets.accounts
  };
}

export function listVaultPublicAccounts(vaultOrSession) {
  return structuredClone(vaultOrSession.publicAccounts ?? []);
}

export function exportVaultPublicMetadata(vaultOrSession) {
  return {
    schema: PUBLIC_EXPORT_SCHEMA,
    vaultId: vaultOrSession.vaultId,
    createdAtUnixMs: vaultOrSession.createdAtUnixMs,
    publicAccounts: listVaultPublicAccounts(vaultOrSession),
    boundary: "Public local test metadata only. Secret key material is excluded."
  };
}

export function exportLocalWalletPublicMetadata(vaultOrSession, {
  updatedAtUnixMs = Date.now().toString()
} = {}) {
  return {
    schema: LOCAL_WALLET_PUBLIC_METADATA_SCHEMA,
    vaultId: vaultOrSession.vaultId,
    createdAtUnixMs: vaultOrSession.createdAtUnixMs,
    updatedAtUnixMs: String(updatedAtUnixMs),
    accounts: listVaultPublicAccounts(vaultOrSession).map(localWalletPublicAccount),
    boundary: "Public local wallet metadata only. Signing material, vault encryption payloads, credentials, and webhooks are excluded."
  };
}

export function validateLocalWalletPublicMetadata(metadata, { expectedChainId } = {}) {
  const errors = [];
  if (!metadata || typeof metadata !== "object") {
    return verificationResult({ errors: ["metadata-not-object"], metadata });
  }
  if (metadata.schema !== LOCAL_WALLET_PUBLIC_METADATA_SCHEMA) {
    errors.push("wrong-schema");
  }
  if (containsSecretMaterial(metadata)) {
    errors.push("secret-material");
  }
  if (!isHex32(metadata.vaultId)) {
    errors.push("bad-vault-id");
  }
  if (!isUintString(metadata.createdAtUnixMs) || !isUintString(metadata.updatedAtUnixMs)) {
    errors.push("bad-time");
  }
  if (!Array.isArray(metadata.accounts) || metadata.accounts.length === 0) {
    errors.push("missing-accounts");
  }

  let chainIdMatch = true;
  for (const account of metadata.accounts ?? []) {
    const accountErrors = validateLocalWalletPublicAccount(account, { expectedChainId });
    for (const error of accountErrors.errors) {
      errors.push(error);
    }
    chainIdMatch = chainIdMatch && accountErrors.chainIdMatch;
  }

  return verificationResult({ errors, metadata, chainIdMatch });
}

export function addEncryptedTestVaultAccount({
  vault,
  password,
  label = "local-account",
  signerRole = "agent",
  createdAtUnixMs = Date.now().toString(),
  privateKey,
  signerId,
  chainId = vault.publicAccounts?.[0]?.chainId ?? DEFAULT_LOCAL_WALLET_CHAIN_ID,
  lastKnownNonce = "0"
}) {
  const secrets = decryptVaultSecrets({ vault, password });
  const account = createVaultAccount({
    label,
    signerRole,
    createdAtUnixMs,
    privateKey,
    signerId,
    chainId,
    lastKnownNonce
  });
  const accounts = [...secrets.accounts, account];
  return encryptVaultSecrets({
    password,
    vaultId: vault.vaultId,
    createdAtUnixMs: vault.createdAtUnixMs,
    publicAccounts: accounts.map(publicAccount),
    secrets: {
      schema: VAULT_SECRETS_SCHEMA,
      accounts
    }
  });
}

export function rotateEncryptedTestVaultAccount({
  vault,
  password,
  signerKeyId,
  label,
  createdAtUnixMs = Date.now().toString(),
  privateKey,
  chainId
}) {
  const secrets = decryptVaultSecrets({ vault, password });
  const index = secrets.accounts.findIndex((account) => account.signerKeyId === signerKeyId);
  if (index === -1) {
    throw new Error(`unknown signer key id: ${signerKeyId}`);
  }

  const previous = { ...secrets.accounts[index], active: false, rotatedAtUnixMs: createdAtUnixMs };
  const replacement = createVaultAccount({
    label: label ?? previous.label,
    signerRole: previous.signerRole,
    createdAtUnixMs,
    privateKey,
    signerId: previous.signerId,
    chainId: chainId ?? previous.chainId ?? DEFAULT_LOCAL_WALLET_CHAIN_ID,
    lastKnownNonce: previous.lastKnownNonce ?? "0",
    rotatedFromSignerKeyId: previous.signerKeyId
  });
  const accounts = [...secrets.accounts.slice(0, index), previous, replacement, ...secrets.accounts.slice(index + 1)];

  return encryptVaultSecrets({
    password,
    vaultId: vault.vaultId,
    createdAtUnixMs: vault.createdAtUnixMs,
    publicAccounts: accounts.map(publicAccount),
    secrets: {
      schema: VAULT_SECRETS_SCHEMA,
      accounts
    }
  });
}

export async function signLocalTransactionWithVault({
  vault,
  password,
  signerKeyId,
  document,
  chainId,
  nonce,
  issuedAtUnixMs = Date.now().toString()
}) {
  const session = unlockEncryptedTestVault({ vault, password });
  const account = session.accounts.find(
    (candidate) => candidate.signerKeyId === signerKeyId && candidate.active !== false
  );
  if (!account) {
    throw new Error(`unknown active signer key id: ${signerKeyId}`);
  }

  const unsigned = buildUnsignedLocalTransactionEnvelope({
    document,
    chainId,
    nonce,
    signerId: account.signerId,
    signerKeyId: account.signerKeyId,
    signerRole: account.signerRole,
    publicKey: account.publicKey,
    issuedAtUnixMs
  });
  const signature = await signDigest({ digest: unsigned.signingDigest, privateKey: account.privateKey });
  return {
    ...unsigned,
    signature
  };
}

export function verifyLocalTransactionSignature({ document, envelope, context }) {
  return validateLocalTransactionEnvelope({ document, envelope, context });
}

function encryptVaultSecrets({
  password,
  publicAccounts,
  secrets,
  createdAtUnixMs,
  vaultId = randomBytes32()
}) {
  requirePassword(password);
  const salt = randomBytes(16);
  const iv = randomBytes(12);
  const kdf = {
    name: "scrypt",
    salt: bytesToHex(salt),
    N: 16384,
    r: 8,
    p: 1,
    keyLength: 32
  };
  const key = scryptSync(password, salt, kdf.keyLength, { N: kdf.N, r: kdf.r, p: kdf.p });
  const cipher = createCipheriv("aes-256-gcm", key, iv);
  const ciphertext = Buffer.concat([
    cipher.update(JSON.stringify(secrets), "utf8"),
    cipher.final()
  ]);

  return {
    schema: VAULT_SCHEMA,
    vaultId,
    createdAtUnixMs,
    kdf,
    cipher: {
      name: "aes-256-gcm",
      iv: bytesToHex(iv),
      authTag: bytesToHex(cipher.getAuthTag())
    },
    ciphertext: bytesToHex(ciphertext),
    publicAccounts
  };
}

function decryptVaultSecrets({ vault, password }) {
  requirePassword(password);
  if (vault?.schema !== VAULT_SCHEMA) {
    throw new Error("unsupported local test vault schema");
  }
  const salt = Buffer.from(vault.kdf.salt.slice(2), "hex");
  const key = scryptSync(password, salt, vault.kdf.keyLength, {
    N: vault.kdf.N,
    r: vault.kdf.r,
    p: vault.kdf.p
  });
  const decipher = createDecipheriv("aes-256-gcm", key, Buffer.from(vault.cipher.iv.slice(2), "hex"));
  decipher.setAuthTag(Buffer.from(vault.cipher.authTag.slice(2), "hex"));
  const plaintext = Buffer.concat([
    decipher.update(Buffer.from(vault.ciphertext.slice(2), "hex")),
    decipher.final()
  ]);
  const secrets = JSON.parse(plaintext.toString("utf8"));
  if (secrets.schema !== VAULT_SECRETS_SCHEMA || !Array.isArray(secrets.accounts)) {
    throw new Error("invalid local test vault payload");
  }
  return secrets;
}

function createVaultAccount({
  label,
  signerRole,
  createdAtUnixMs,
  privateKey = randomPrivateKey(),
  signerId,
  rotatedFromSignerKeyId,
  chainId = DEFAULT_LOCAL_WALLET_CHAIN_ID,
  lastKnownNonce = "0"
}) {
  if (LOCAL_ALPHA_SIGNER_ROLES[signerRole] === undefined) {
    throw new Error(`unsupported signer role: ${signerRole}`);
  }
  if (!isUintString(String(chainId))) {
    throw new Error(`unsupported wallet chain id: ${chainId}`);
  }
  if (!isUintString(String(lastKnownNonce))) {
    throw new Error(`invalid wallet last known nonce: ${lastKnownNonce}`);
  }
  const publicKey = publicKeyFromPrivateKey(privateKey);
  const publicKeyHash = keccakUtf8(publicKey);
  const derivedSignerId = keccakUtf8(`flowchain.local-alpha.signer:${publicKey}`);
  const effectiveSignerId = signerId ?? derivedSignerId;
  if (!isHex32(effectiveSignerId)) {
    throw new Error(`invalid signer id: ${effectiveSignerId}`);
  }
  const account = {
    label,
    accountId: effectiveSignerId,
    address: effectiveSignerId,
    signerRole,
    signerRoleCode: LOCAL_ALPHA_SIGNER_ROLES[signerRole],
    signerId: effectiveSignerId,
    signerKeyId: keccakUtf8(`flowchain.local-alpha.signer-key:${publicKey}`),
    publicKey,
    publicKeyHash,
    keyScheme: LOCAL_WALLET_KEY_SCHEME,
    chainId: String(chainId),
    lastKnownNonce: String(lastKnownNonce),
    nextNonce: nextNonce(lastKnownNonce),
    createdAtUnixMs,
    status: "active",
    active: true,
    privateKey
  };
  if (rotatedFromSignerKeyId) {
    account.rotatedFromSignerKeyId = rotatedFromSignerKeyId;
  }
  return account;
}

function publicAccount(account) {
  const {
    privateKey,
    ...metadata
  } = account;
  return metadata;
}

function localWalletPublicAccount(account) {
  return {
    accountId: account.accountId ?? account.signerId,
    address: account.address ?? account.signerId,
    signerId: account.signerId,
    signerKeyId: account.signerKeyId,
    signerRole: account.signerRole,
    signerRoleCode: account.signerRoleCode,
    publicKey: account.publicKey,
    publicKeyHash: account.publicKeyHash,
    keyScheme: account.keyScheme ?? LOCAL_WALLET_KEY_SCHEME,
    label: account.label,
    status: account.active === false ? "rotated" : (account.status ?? "active"),
    active: account.active !== false,
    createdAtUnixMs: account.createdAtUnixMs,
    chainId: String(account.chainId ?? DEFAULT_LOCAL_WALLET_CHAIN_ID),
    lastKnownNonce: String(account.lastKnownNonce ?? "0"),
    nextNonce: String(account.nextNonce ?? nextNonce(account.lastKnownNonce ?? "0")),
    rotatedFromSignerKeyId: account.rotatedFromSignerKeyId
  };
}

function randomPrivateKey() {
  for (;;) {
    const candidate = bytesToHex(randomBytes(32));
    try {
      publicKeyFromPrivateKey(candidate);
      return candidate;
    } catch {
      // Try again if random bytes are outside the secp256k1 private-key range.
    }
  }
}

function randomBytes32() {
  return bytesToHex(randomBytes(32));
}

function requirePassword(password) {
  if (typeof password !== "string" || password.length < 8) {
    throw new Error("local test vault password must be at least 8 characters");
  }
}

function validateLocalWalletPublicAccount(account, { expectedChainId } = {}) {
  const errors = [];
  let chainIdMatch = true;
  if (!account || typeof account !== "object") {
    return { errors: ["bad-account"], chainIdMatch: false };
  }
  if (!isHex32(account.accountId) || !isHex32(account.address) || !isHex32(account.signerId) || !isHex32(account.signerKeyId)) {
    errors.push("bad-account-id");
  }
  if (account.accountId !== account.signerId || account.address !== account.signerId) {
    errors.push("address-mismatch");
  }
  if (account.keyScheme !== LOCAL_WALLET_KEY_SCHEME) {
    errors.push("bad-key-scheme");
  }
  if (LOCAL_ALPHA_SIGNER_ROLES[account.signerRole] !== account.signerRoleCode) {
    errors.push("bad-signer-role");
  }
  if (!isPublicKey(account.publicKey)) {
    errors.push("malformed-public-key");
  } else {
    const signerId = keccakUtf8(`flowchain.local-alpha.signer:${account.publicKey}`);
    const signerKeyId = keccakUtf8(`flowchain.local-alpha.signer-key:${account.publicKey}`);
    if (account.signerId !== signerId || account.signerKeyId !== signerKeyId) {
      errors.push("public-key-mismatch");
    }
  }
  if (!isUintString(account.createdAtUnixMs) || !isUintString(account.chainId) || !isUintString(account.lastKnownNonce) || !isUintString(account.nextNonce)) {
    errors.push("bad-account-metadata");
  }
  if (expectedChainId !== undefined && String(account.chainId) !== String(expectedChainId)) {
    chainIdMatch = false;
    errors.push("wrong-chain-id");
  }
  return { errors, chainIdMatch };
}

function verificationResult({ errors, metadata, chainIdMatch = errors.length === 0 }) {
  return {
    schema: "flowchain.local_wallet_public_metadata_verification.v0",
    valid: errors.length === 0,
    secretFree: !containsSecretMaterial(metadata),
    chainIdMatch,
    accountCount: Array.isArray(metadata?.accounts) ? metadata.accounts.length : 0,
    errors: [...new Set(errors)]
  };
}

function containsSecretMaterial(value) {
  const serialized = JSON.stringify(value);
  return /"(privateKey|private_key|seedPhrase|mnemonic|ciphertext|authTag|password|rpcUrl|rpc_url|apiKey|api_key|webhookUrl|webhook_url)"\s*:/i.test(serialized) ||
    /https:\/\/hooks\.slack\.com|https:\/\/discord\.com\/api\/webhooks|BEGIN RSA PRIVATE KEY|BEGIN OPENSSH PRIVATE KEY/i.test(serialized);
}

function isHex32(value) {
  return typeof value === "string" && /^0x[0-9a-fA-F]{64}$/.test(value);
}

function isPublicKey(value) {
  return typeof value === "string" && /^0x([0-9a-fA-F]{66}|[0-9a-fA-F]{130})$/.test(value);
}

function isUintString(value) {
  return typeof value === "string" && /^[0-9]+$/.test(value);
}

function nextNonce(value) {
  return (BigInt(value) + 1n).toString();
}
