const { createCipheriv, randomBytes, scryptSync } = require("node:crypto");
const { existsSync, mkdirSync, readFileSync, writeFileSync } = require("node:fs");
const path = require("node:path");

const VAULT_SCHEMA = "flowmemory.crypto.local-test-vault.v0";
const VAULT_SECRETS_SCHEMA = "flowmemory.crypto.local-test-vault-secrets.v0";
const LOCAL_WALLET_PUBLIC_METADATA_SCHEMA = "flowmemory.local_wallet_public_metadata.v0";
const LOCAL_WALLET_KEY_SCHEME = "secp256k1";
const DEFAULT_LOCAL_WALLET_CHAIN_ID = "31337";
const LOCAL_ALPHA_SIGNER_ROLES = Object.freeze({
  operator: 1,
  agent: 2,
  verifier: 3,
  hardware: 4,
  user: 10,
  validator: 11,
  bridgeRelayer: 12,
  bridgeReleaseAuthority: 13,
  emergencyOperator: 14,
});

let nobleModules;

async function loadNobleModules() {
  if (nobleModules === undefined) {
    nobleModules = Promise.all([
      import("@noble/secp256k1"),
      import("@noble/hashes/sha3.js"),
    ]).then(([secp, sha3]) => ({ secp, sha3 }));
  }
  return nobleModules;
}

function walletPaths(userDataPath) {
  const walletDir = path.join(userDataPath, "wallet");
  return {
    walletDir,
    vaultPath: path.join(walletDir, "flowmemory-wallet-vault.local.json"),
    metadataPath: path.join(walletDir, "flowmemory-wallet-public-metadata.json"),
  };
}

function publicDesktopWalletStatus(userDataPath) {
  const paths = walletPaths(userDataPath);
  const metadata = existsSync(paths.metadataPath) ? readJson(paths.metadataPath) : null;
  const accounts = Array.isArray(metadata?.accounts) ? metadata.accounts : [];
  const primaryAccount = accounts.find((entry) => entry !== null && typeof entry === "object" && !Array.isArray(entry)) ?? null;
  return {
    schema: "flowmemory.control_plane.local_wallet_public_status.v0",
    exists: metadata !== null,
    metadataPath: paths.metadataPath,
    account: primaryAccount,
    accounts,
    secretMaterialReturned: false,
    localOnly: true,
    desktopLocal: true,
  };
}

async function createLocalDesktopWallet(userDataPath, payload = {}) {
  const request = parseWalletCreatePayload(payload);
  const paths = walletPaths(userDataPath);
  mkdirSync(paths.walletDir, { recursive: true });

  if (!request.replace && existsSync(paths.vaultPath) && existsSync(paths.metadataPath)) {
    return {
      ...publicDesktopWalletStatus(userDataPath),
      schema: "flowmemory.control_plane.local_wallet_create_result.v0",
      created: false,
      alreadyExists: true,
      vaultPath: paths.vaultPath,
      note: "Existing encrypted local wallet vault was left unchanged. Enable replace to rotate to a new wallet.",
    };
  }

  const vault = await createEncryptedDesktopVault({
    password: request.password,
    label: request.label,
    signerRole: "user",
    chainId: request.chainId,
  });
  const metadata = exportLocalWalletPublicMetadata(vault);
  writeJson(paths.vaultPath, vault);
  writeJson(paths.metadataPath, metadata);

  const account = Array.isArray(metadata.accounts) ? metadata.accounts[0] : null;
  return {
    schema: "flowmemory.control_plane.local_wallet_create_result.v0",
    created: true,
    alreadyExists: false,
    account,
    accounts: metadata.accounts,
    vaultPath: paths.vaultPath,
    metadataPath: paths.metadataPath,
    chainId: request.chainId,
    keyScheme: account?.keyScheme ?? LOCAL_WALLET_KEY_SCHEME,
    secretMaterialReturned: false,
    credentialStored: false,
    localOnly: true,
    desktopLocal: true,
  };
}

async function createEncryptedDesktopVault({
  password,
  label,
  signerRole,
  createdAtUnixMs = Date.now().toString(),
  privateKey,
  chainId = DEFAULT_LOCAL_WALLET_CHAIN_ID,
  lastKnownNonce = "0",
}) {
  requirePassword(password);
  const account = await createVaultAccount({ label, signerRole, createdAtUnixMs, privateKey, chainId, lastKnownNonce });
  return encryptVaultSecrets({
    password,
    publicAccounts: [publicAccount(account)],
    secrets: {
      schema: VAULT_SECRETS_SCHEMA,
      accounts: [account],
    },
    createdAtUnixMs,
  });
}

function encryptVaultSecrets({
  password,
  publicAccounts,
  secrets,
  createdAtUnixMs,
  vaultId = randomBytes32(),
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
    keyLength: 32,
  };
  const key = scryptSync(password, salt, kdf.keyLength, { N: kdf.N, r: kdf.r, p: kdf.p });
  const cipher = createCipheriv("aes-256-gcm", key, iv);
  const ciphertext = Buffer.concat([
    cipher.update(JSON.stringify(secrets), "utf8"),
    cipher.final(),
  ]);

  return {
    schema: VAULT_SCHEMA,
    vaultId,
    createdAtUnixMs,
    kdf,
    cipher: {
      name: "aes-256-gcm",
      iv: bytesToHex(iv),
      authTag: bytesToHex(cipher.getAuthTag()),
    },
    ciphertext: bytesToHex(ciphertext),
    publicAccounts,
  };
}

async function createVaultAccount({
  label,
  signerRole,
  createdAtUnixMs,
  privateKey,
  chainId = DEFAULT_LOCAL_WALLET_CHAIN_ID,
  lastKnownNonce = "0",
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
  const effectivePrivateKey = privateKey ?? await randomPrivateKey();
  const publicKey = await publicKeyFromPrivateKey(effectivePrivateKey);
  const publicKeyHash = await keccakUtf8(publicKey);
  const signerId = await keccakUtf8(`flowmemory.local-operator.signer:${publicKey}`);
  return {
    label,
    accountId: signerId,
    address: signerId,
    signerRole,
    signerRoleCode: LOCAL_ALPHA_SIGNER_ROLES[signerRole],
    signerId,
    signerKeyId: await keccakUtf8(`flowmemory.local-operator.signer-key:${publicKey}`),
    publicKey,
    publicKeyHash,
    keyScheme: LOCAL_WALLET_KEY_SCHEME,
    chainId: String(chainId),
    lastKnownNonce: String(lastKnownNonce),
    nextNonce: nextNonce(lastKnownNonce),
    createdAtUnixMs,
    status: "active",
    active: true,
    privateKey: effectivePrivateKey,
  };
}

function publicAccount(account) {
  const { privateKey, ...metadata } = account;
  return metadata;
}

function exportLocalWalletPublicMetadata(vault, { updatedAtUnixMs = Date.now().toString() } = {}) {
  return {
    schema: LOCAL_WALLET_PUBLIC_METADATA_SCHEMA,
    vaultId: vault.vaultId,
    createdAtUnixMs: vault.createdAtUnixMs,
    updatedAtUnixMs: String(updatedAtUnixMs),
    accounts: (vault.publicAccounts ?? []).map(localWalletPublicAccount),
    boundary: "Public local wallet metadata only. Signing material, vault encryption payloads, credentials, and webhooks are excluded.",
  };
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
    status: account.active === false ? "rotated" : account.status ?? "active",
    active: account.active !== false,
    createdAtUnixMs: account.createdAtUnixMs,
    chainId: String(account.chainId ?? DEFAULT_LOCAL_WALLET_CHAIN_ID),
    lastKnownNonce: String(account.lastKnownNonce ?? "0"),
    nextNonce: String(account.nextNonce ?? nextNonce(account.lastKnownNonce ?? "0")),
    rotatedFromSignerKeyId: account.rotatedFromSignerKeyId,
  };
}

async function randomPrivateKey() {
  for (;;) {
    const candidate = bytesToHex(randomBytes(32));
    try {
      await publicKeyFromPrivateKey(candidate);
      return candidate;
    } catch {
      // Retry if the random bytes do not form a valid secp256k1 secret.
    }
  }
}

async function publicKeyFromPrivateKey(privateKeyHex) {
  const { secp } = await loadNobleModules();
  return bytesToHex(secp.getPublicKey(hexToBytes(privateKeyHex, 32)));
}

async function keccakUtf8(value) {
  const { sha3 } = await loadNobleModules();
  return bytesToHex(sha3.keccak_256(Buffer.from(String(value), "utf8")));
}

function parseWalletCreatePayload(payload) {
  if (payload === null || typeof payload !== "object" || Array.isArray(payload)) {
    throw new Error("wallet creation payload must be an object");
  }
  const password = typeof payload.password === "string" ? payload.password : "";
  if (password.length < 8) {
    throw new Error("wallet vault passphrase must be at least 8 characters");
  }
  const chainId = typeof payload.chainId === "string" && /^\d+$/.test(payload.chainId) ? payload.chainId : DEFAULT_LOCAL_WALLET_CHAIN_ID;
  return {
    label: labelSlug(payload.label),
    password,
    chainId,
    replace: payload.replace === true,
  };
}

function labelSlug(value) {
  const label = typeof value === "string" && value.trim().length > 0 ? value.trim() : "flowmemory-wallet";
  const slug = label.toLowerCase().replace(/[^a-z0-9._-]+/g, "-").replace(/^-+|-+$/g, "");
  return slug.length > 0 ? slug.slice(0, 64) : "flowmemory-wallet";
}

function requirePassword(password) {
  if (typeof password !== "string" || password.length < 8) {
    throw new Error("wallet vault passphrase must be at least 8 characters");
  }
}

function randomBytes32() {
  return bytesToHex(randomBytes(32));
}

function bytesToHex(bytes) {
  return `0x${Buffer.from(bytes).toString("hex")}`;
}

function hexToBytes(value, expectedLength) {
  if (typeof value !== "string") {
    throw new TypeError("hex value must be a string");
  }
  const raw = value.startsWith("0x") ? value.slice(2) : value;
  if (raw.length % 2 !== 0 || !/^[0-9a-fA-F]*$/.test(raw)) {
    throw new Error(`invalid hex value: ${value}`);
  }
  const bytes = Uint8Array.from(Buffer.from(raw, "hex"));
  if (expectedLength !== undefined && bytes.length !== expectedLength) {
    throw new Error(`expected ${expectedLength} bytes, got ${bytes.length}`);
  }
  return bytes;
}

function isUintString(value) {
  return typeof value === "string" && /^[0-9]+$/.test(value);
}

function nextNonce(value) {
  return (BigInt(value) + 1n).toString();
}

function readJson(filePath) {
  return JSON.parse(readFileSync(filePath, "utf8"));
}

function writeJson(filePath, value) {
  writeFileSync(filePath, `${JSON.stringify(value, null, 2)}\n`);
}

module.exports = {
  createLocalDesktopWallet,
  publicDesktopWalletStatus,
  walletPaths,
};
