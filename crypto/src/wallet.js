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

export function createEncryptedTestVault({
  password,
  label = "local-operator",
  signerRole = "operator",
  createdAtUnixMs = Date.now().toString(),
  privateKey
} = {}) {
  requirePassword(password);
  const account = createVaultAccount({ label, signerRole, createdAtUnixMs, privateKey });
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

export function addEncryptedTestVaultAccount({
  vault,
  password,
  label = "local-account",
  signerRole = "agent",
  createdAtUnixMs = Date.now().toString(),
  privateKey,
  signerId
}) {
  const secrets = decryptVaultSecrets({ vault, password });
  const account = createVaultAccount({ label, signerRole, createdAtUnixMs, privateKey, signerId });
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
  privateKey
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
  rotatedFromSignerKeyId
}) {
  if (LOCAL_ALPHA_SIGNER_ROLES[signerRole] === undefined) {
    throw new Error(`unsupported signer role: ${signerRole}`);
  }
  const publicKey = publicKeyFromPrivateKey(privateKey);
  const publicKeyHash = keccakUtf8(publicKey);
  const account = {
    label,
    signerRole,
    signerRoleCode: LOCAL_ALPHA_SIGNER_ROLES[signerRole],
    signerId: signerId ?? keccakUtf8(`flowchain.local-alpha.signer:${publicKey}`),
    signerKeyId: keccakUtf8(`flowchain.local-alpha.signer-key:${publicKey}`),
    publicKey,
    publicKeyHash,
    createdAtUnixMs,
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
