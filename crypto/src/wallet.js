import { createCipheriv, createDecipheriv, randomBytes, scryptSync } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { publicKeyFromPrivateKey, signDigest } from "./attestations.js";
import { bytesToHex, hexToBytes } from "./encoding.js";
import { keccakUtf8 } from "./hashes.js";
import {
  createLocalTransactionEnvelope,
  localSignerPublicMetadata,
  validateLocalTransactionEnvelope
} from "./transactions.js";

const packageRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");

export const DEFAULT_WALLET_PATH = resolve(packageRoot, ".wallet", "flowchain-wallet.local.json");
export const WALLET_SCHEMA = "flowchain.local_wallet_vault.v0";
export const WALLET_PUBLIC_METADATA_SCHEMA = "flowchain.local_wallet_public_metadata.v0";

const DEFAULT_KDF = Object.freeze({
  name: "scrypt",
  salt: null,
  N: 16384,
  r: 8,
  p: 1,
  keyLength: 32
});

const CIPHER = "aes-256-gcm";

export function createWalletVault({
  password,
  vaultPath = DEFAULT_WALLET_PATH,
  label = "flowchain-local-operator",
  signerRole = "operator",
  force = false,
  now = Date.now()
}) {
  assertPassword(password);
  if (existsSync(vaultPath) && !force) {
    throw new Error(`wallet vault already exists: ${vaultPath}`);
  }

  const account = createWalletAccount({ label, signerRole, now });
  const publicMetadata = buildPublicMetadata({
    accounts: [publicAccount(account)],
    createdAtUnixMs: String(now),
    updatedAtUnixMs: String(now)
  });
  const secret = {
    schema: "flowchain.local_wallet_secret.v0",
    accounts: [account]
  };
  const vault = encryptVault({ publicMetadata, secret, password });
  writeVault(vaultPath, vault);
  return vault.public;
}

export function unlockWalletVault({ password, vaultPath = DEFAULT_WALLET_PATH }) {
  assertPassword(password);
  const vault = readVault(vaultPath);
  const secret = decryptVault({ vault, password });
  return { vault, publicMetadata: vault.public, secret };
}

export function listWalletPublicAccounts({ vaultPath = DEFAULT_WALLET_PATH } = {}) {
  return readVault(vaultPath).public;
}

export function rotateWalletAccount({
  password,
  vaultPath = DEFAULT_WALLET_PATH,
  label = "flowchain-local-account",
  signerRole = "operator",
  now = Date.now()
}) {
  const { vault, publicMetadata, secret } = unlockWalletVault({ password, vaultPath });
  const account = createWalletAccount({ label, signerRole, now });
  secret.accounts.push(account);
  publicMetadata.accounts.push(publicAccount(account));
  publicMetadata.updatedAtUnixMs = String(now);
  const updated = encryptVault({ publicMetadata, secret, password, previousVault: vault });
  writeVault(vaultPath, updated);
  return updated.public;
}

export async function signWalletTransaction({
  password,
  payload,
  vaultPath = DEFAULT_WALLET_PATH,
  accountId,
  chainId = "31337",
  nonce,
  issuedAtUnixMs = Date.now(),
  expiresAtUnixMs = Number(issuedAtUnixMs) + 86_400_000
}) {
  const { vault, publicMetadata, secret } = unlockWalletVault({ password, vaultPath });
  const account = selectSecretAccount(secret.accounts, accountId);
  const publicEntry = publicMetadata.accounts.find((entry) => entry.accountId === account.accountId);
  if (!publicEntry) {
    throw new Error(`wallet public metadata is missing account ${account.accountId}`);
  }

  const selectedNonce = String(nonce ?? account.nextNonce ?? publicEntry.nextNonce ?? "1");
  const signer = {
    accountId: publicEntry.accountId,
    signerId: publicEntry.signerId,
    signerKeyId: publicEntry.signerKeyId,
    signerRole: publicEntry.signerRole,
    signerRoleCode: publicEntry.signerRoleCode,
    publicKey: publicEntry.publicKey
  };
  const unsigned = createLocalTransactionEnvelope({
    chainId,
    nonce: selectedNonce,
    payload,
    signer,
    issuedAtUnixMs: String(issuedAtUnixMs),
    expiresAtUnixMs: String(expiresAtUnixMs)
  });
  const signature = await signDigest({ digest: unsigned.signingDigest, privateKey: account.privateKey });
  const envelope = { ...unsigned, signature };

  const nextNonce = (BigInt(selectedNonce) + 1n).toString();
  account.nextNonce = nextNonce;
  publicEntry.nextNonce = nextNonce;
  publicMetadata.updatedAtUnixMs = String(issuedAtUnixMs);
  const updated = encryptVault({ publicMetadata, secret, password, previousVault: vault });
  writeVault(vaultPath, updated);

  return envelope;
}

export function verifyWalletTransaction({ envelope, expectedChainId, seenNonces, expectedSignerId } = {}) {
  return validateLocalTransactionEnvelope({
    envelope,
    context: {
      expectedChainId,
      expectedSignerId,
      seenNonces
    }
  });
}

export function exportWalletPublicMetadata({ vaultPath = DEFAULT_WALLET_PATH, outPath } = {}) {
  const metadata = listWalletPublicAccounts({ vaultPath });
  assertPublicMetadataHasNoSecrets(metadata);
  if (outPath) {
    writeJson(outPath, metadata);
  }
  return metadata;
}

export function importWalletPublicMetadata({ vaultPath = DEFAULT_WALLET_PATH, metadata, inPath, now = Date.now() }) {
  const imported = metadata ?? readJson(inPath);
  assertPublicMetadataHasNoSecrets(imported);
  if (imported?.schema !== WALLET_PUBLIC_METADATA_SCHEMA) {
    throw new Error("unsupported wallet public metadata schema");
  }

  const vault = readVault(vaultPath);
  const existing = vault.public.importedAccounts ?? [];
  const byAccount = new Map(existing.map((entry) => [entry.accountId, entry]));
  for (const account of imported.accounts ?? []) {
    byAccount.set(account.accountId, {
      ...account,
      importedFromVaultId: imported.vaultId,
      importedAtUnixMs: String(now)
    });
  }
  vault.public.importedAccounts = [...byAccount.values()].sort((a, b) =>
    String(a.accountId).localeCompare(String(b.accountId))
  );
  vault.public.updatedAtUnixMs = String(now);
  writeVault(vaultPath, vault);
  return vault.public;
}

export function createWalletAccount({ label, signerRole = "operator", now = Date.now() }) {
  const privateKey = randomPrivateKey();
  const publicKey = publicKeyFromPrivateKey(privateKey);
  const publicMetadata = localSignerPublicMetadata({ publicKey, signerRole });
  return {
    ...publicMetadata,
    label,
    status: "active",
    createdAtUnixMs: String(now),
    nextNonce: "1",
    privateKey
  };
}

export function assertPublicMetadataHasNoSecrets(metadata) {
  const body = JSON.stringify(metadata);
  if (/"privateKey"|"encrypted"|"authTag"|"iv"|"cipher"/i.test(body)) {
    throw new Error("public wallet metadata must not contain vault ciphertext or private key material");
  }
}

function buildPublicMetadata({ accounts, createdAtUnixMs, updatedAtUnixMs }) {
  const vaultId = keccakUtf8(
    `flowchain.local.wallet.v0:${createdAtUnixMs}:${accounts.map((account) => account.publicKey).join(":")}`
  );
  return {
    schema: WALLET_PUBLIC_METADATA_SCHEMA,
    vaultId,
    createdAtUnixMs,
    updatedAtUnixMs,
    accounts
  };
}

function publicAccount(account) {
  const {
    privateKey: _privateKey,
    ...publicFields
  } = account;
  return publicFields;
}

function encryptVault({ publicMetadata, secret, password, previousVault }) {
  const kdf = {
    ...DEFAULT_KDF,
    salt: bytesToHex(randomBytes(16))
  };
  const key = deriveKey(password, kdf);
  const iv = randomBytes(12);
  const cipher = createCipheriv(CIPHER, key, iv);
  const plaintext = Buffer.from(JSON.stringify(secret), "utf8");
  const ciphertext = Buffer.concat([cipher.update(plaintext), cipher.final()]);
  const authTag = cipher.getAuthTag();

  return {
    schema: WALLET_SCHEMA,
    version: 1,
    createdAtUnixMs: previousVault?.createdAtUnixMs ?? publicMetadata.createdAtUnixMs,
    updatedAtUnixMs: publicMetadata.updatedAtUnixMs,
    kdf,
    cipher: {
      name: CIPHER,
      iv: bytesToHex(iv),
      authTag: bytesToHex(authTag)
    },
    encrypted: bytesToHex(ciphertext),
    public: publicMetadata
  };
}

function decryptVault({ vault, password }) {
  if (vault.schema !== WALLET_SCHEMA) {
    throw new Error("unsupported wallet vault schema");
  }
  const key = deriveKey(password, vault.kdf);
  const decipher = createDecipheriv(CIPHER, key, hexToBytes(vault.cipher.iv));
  decipher.setAuthTag(hexToBytes(vault.cipher.authTag));
  const plaintext = Buffer.concat([
    decipher.update(hexToBytes(vault.encrypted)),
    decipher.final()
  ]);
  return JSON.parse(plaintext.toString("utf8"));
}

function deriveKey(password, kdf) {
  if (kdf?.name !== "scrypt") {
    throw new Error("unsupported wallet kdf");
  }
  return scryptSync(String(password), hexToBytes(kdf.salt), kdf.keyLength, {
    N: kdf.N,
    r: kdf.r,
    p: kdf.p
  });
}

function randomPrivateKey() {
  for (let attempt = 0; attempt < 100; attempt += 1) {
    const candidate = bytesToHex(randomBytes(32));
    if (candidate !== "0x0000000000000000000000000000000000000000000000000000000000000000") {
      try {
        publicKeyFromPrivateKey(candidate);
        return candidate;
      } catch {
        // Try another candidate.
      }
    }
  }
  throw new Error("failed to generate a valid secp256k1 private key");
}

function selectSecretAccount(accounts, accountId) {
  if (!accounts?.length) {
    throw new Error("wallet contains no accounts");
  }
  if (!accountId) {
    return accounts[0];
  }
  const account = accounts.find((entry) => entry.accountId === accountId || entry.signerId === accountId);
  if (!account) {
    throw new Error(`wallet account not found: ${accountId}`);
  }
  return account;
}

function readVault(vaultPath) {
  return readJson(vaultPath);
}

function writeVault(vaultPath, vault) {
  mkdirSync(dirname(vaultPath), { recursive: true });
  writeFileSync(vaultPath, `${JSON.stringify(vault, null, 2)}\n`, { mode: 0o600 });
}

function readJson(path) {
  return JSON.parse(readFileSync(resolve(path), "utf8"));
}

function writeJson(path, value) {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, `${JSON.stringify(value, null, 2)}\n`, { mode: 0o600 });
}

function assertPassword(password) {
  if (!password || String(password).length < 8) {
    throw new Error("wallet password must be at least 8 characters");
  }
}
