import {
  pilotBridgeCreditAckId,
  pilotEmergencyControlId,
  pilotReleaseEvidenceId,
  pilotWithdrawalIntentId
} from "./objects.js";
import { keccakUtf8 } from "./hashes.js";
import { assertPublicPilotMetadataContainsNoSecrets } from "./pilot-envelope-validation.js";

export const PILOT_OPERATOR_CONFIG_SCHEMA = "flowchain.real_value_pilot.operator_config.v0";
export const PILOT_PUBLIC_METADATA_SCHEMA = "flowchain.real_value_pilot.public_metadata.v0";
const SUPPORTED_PILOT_CHAIN_IDS = new Set([31337, 84532, 8453]);
const BASE_MAINNET_CHAIN_ID = 8453;
const BASE_MAINNET_MAX_USDC6_CAP = 25_000_000n;

export function createPilotOperatorConfigFromEnv({
  env = process.env,
  createdAtUnixMs = Date.now().toString()
} = {}) {
  const chainId = parsePilotChainId(requiredEnv(env, "FLOWCHAIN_PILOT_CHAIN_ID"));
  const contractAddress = normalizeAddress(requiredEnv(env, "FLOWCHAIN_PILOT_CONTRACT_ADDRESS"));
  const operatorId = requiredEnv(env, "FLOWCHAIN_PILOT_OPERATOR_ID");
  const pilotCap = {
    capId: requiredEnv(env, "FLOWCHAIN_PILOT_CAP_ID"),
    assetId: requiredEnv(env, "FLOWCHAIN_PILOT_CAP_ASSET_ID"),
    maxAmount: requiredEnv(env, "FLOWCHAIN_PILOT_CAP_MAX_AMOUNT"),
    usedAmount: env.FLOWCHAIN_PILOT_CAP_USED_AMOUNT ?? "0",
    unit: requiredEnv(env, "FLOWCHAIN_PILOT_CAP_UNIT"),
    windowStartsAtUnixMs: requiredEnv(env, "FLOWCHAIN_PILOT_CAP_WINDOW_START_UNIX_MS"),
    windowEndsAtUnixMs: requiredEnv(env, "FLOWCHAIN_PILOT_CAP_WINDOW_END_UNIX_MS"),
    realValuePilot: true,
    productionReady: false
  };

  const config = {
    schema: PILOT_OPERATOR_CONFIG_SCHEMA,
    pilotId: keccakUtf8([
      "flowchain.real-value-pilot.v0",
      chainId,
      contractAddress,
      operatorId,
      pilotCap.capId
    ].join(":")),
    createdAtUnixMs: String(createdAtUnixMs),
    chainId,
    contractAddress,
    operatorId,
    pilotCap,
    runtimeInputs: {
      networkAccess: "env-only",
      signingMaterial: "local-vault-only",
      bridgeRelayer: "explicit-chain-contract-block-range"
    },
    localPaths: {
      configPath: env.FLOWCHAIN_PILOT_CONFIG_PATH ?? "devnet/local/pilot-wallet/operator-config.local.json",
      vaultPath: env.FLOWCHAIN_PILOT_VAULT_PATH ?? "devnet/local/pilot-wallet/operator-vault.json",
      publicMetadataPath:
        env.FLOWCHAIN_PILOT_PUBLIC_METADATA_PATH ?? "devnet/local/pilot-wallet/operator-public-metadata.json"
    },
    nextCommands: [],
    productionReady: false
  };

  config.nextCommands = buildPilotNextCommands(config);
  assertPilotOperatorConfig(config);
  assertOperatorConfigHasNoRuntimeSecrets(config);
  return config;
}

export function buildPilotNextCommands(config) {
  return [
    "npm run deploy:base-sepolia:plan",
    `powershell -NoProfile -ExecutionPolicy Bypass -File infra/scripts/flowchain-wallet-pilot-observe.ps1 -ConfigPath ${config.localPaths.configPath} -FromBlock <from-block> -ToBlock <to-block>`,
    "npm run bridge:local-credit:smoke",
    `npm run wallet:pilot-sign --prefix crypto -- --config ${config.localPaths.configPath} --vault ${config.localPaths.vaultPath} --document <pilot-release-evidence.json> --chain-id ${config.chainId} --nonce <next-nonce> --out <pilot-release-envelope.json>`,
    `npm run wallet:pilot-verify --prefix crypto -- --config ${config.localPaths.configPath} --document <pilot-release-evidence.json> --envelope <pilot-release-envelope.json> --expected-nonce <next-nonce>`
  ];
}

export function exportPilotPublicMetadata({ config, walletMetadata }) {
  const publicAccounts = walletMetadata.accounts ?? walletMetadata.publicAccounts ?? [];
  assertPilotOperatorSignerPresent({ config, publicAccounts });
  const metadata = {
    schema: PILOT_PUBLIC_METADATA_SCHEMA,
    pilotId: config.pilotId,
    createdAtUnixMs: config.createdAtUnixMs,
    chainId: config.chainId,
    contractAddress: config.contractAddress,
    operatorId: config.operatorId,
    pilotCap: config.pilotCap,
    accounts: publicAccounts.map(publicAccountMetadata),
    nextCommands: config.nextCommands,
    productionReady: false,
    boundary: "Public operator metadata only. Signing material and network access values stay local."
  };
  assertPublicPilotMetadataContainsNoSecrets(metadata);
  return metadata;
}

function assertPilotOperatorSignerPresent({ config, publicAccounts }) {
  const operatorAccount = publicAccounts.find(
    (account) =>
      account.signerId === config.operatorId &&
      account.signerRole === "operator" &&
      account.active !== false
  );
  if (!operatorAccount) {
    throw new Error("pilot public metadata requires an active operator signer matching the pilot config");
  }
}

export function buildPilotBridgeCreditAckDocument(input) {
  const document = {
    schema: "flowchain.pilot_bridge_credit_ack.v0",
    pilotBridgeCreditAckId: "0x0000000000000000000000000000000000000000000000000000000000000000",
    chainId: input.chainId,
    contractAddress: normalizeAddress(input.contractAddress),
    operatorId: input.operatorId,
    creditId: input.creditId,
    depositId: input.depositId,
    accountId: input.accountId,
    assetId: input.assetId,
    amount: input.amount,
    acknowledgedAtBlockNumber: input.acknowledgedAtBlockNumber,
    accountNonce: input.accountNonce,
    issuedAtUnixMs: input.issuedAtUnixMs,
    expiresAtUnixMs: input.expiresAtUnixMs,
    pilotCap: input.pilotCap
  };
  document.pilotBridgeCreditAckId = pilotBridgeCreditAckId(document);
  return document;
}

export function buildPilotWithdrawalIntentDocument(input) {
  const document = {
    schema: "flowchain.pilot_withdrawal_intent.v0",
    pilotWithdrawalIntentId: "0x0000000000000000000000000000000000000000000000000000000000000000",
    sourceChainId: input.sourceChainId,
    destinationChainId: input.destinationChainId,
    contractAddress: normalizeAddress(input.contractAddress),
    operatorId: input.operatorId,
    creditId: input.creditId,
    depositId: input.depositId,
    token: normalizeAddress(input.token),
    amount: input.amount,
    flowchainAccount: input.flowchainAccount,
    baseRecipient: normalizeAddress(input.baseRecipient),
    status: input.status ?? "requested",
    requestedAt: input.requestedAt,
    accountNonce: input.accountNonce,
    issuedAtUnixMs: input.issuedAtUnixMs,
    expiresAtUnixMs: input.expiresAtUnixMs,
    pilotCap: input.pilotCap
  };
  document.pilotWithdrawalIntentId = pilotWithdrawalIntentId(document);
  return document;
}

export function buildPilotReleaseEvidenceDocument(input) {
  const document = {
    schema: "flowchain.pilot_release_evidence.v0",
    pilotReleaseEvidenceId: "0x0000000000000000000000000000000000000000000000000000000000000000",
    chainId: input.chainId,
    contractAddress: normalizeAddress(input.contractAddress),
    operatorId: input.operatorId,
    withdrawalIntentId: input.withdrawalIntentId,
    releaseTxHash: input.releaseTxHash,
    releaseLogIndex: input.releaseLogIndex,
    token: normalizeAddress(input.token),
    amount: input.amount,
    recipient: normalizeAddress(input.recipient),
    releasedAtBlockNumber: input.releasedAtBlockNumber,
    releasedAtUnixMs: input.releasedAtUnixMs,
    evidenceHash: input.evidenceHash,
    issuedAtUnixMs: input.issuedAtUnixMs,
    expiresAtUnixMs: input.expiresAtUnixMs,
    pilotCap: input.pilotCap
  };
  document.pilotReleaseEvidenceId = pilotReleaseEvidenceId(document);
  return document;
}

export function buildPilotEmergencyControlDocument(input) {
  const document = {
    schema: "flowchain.pilot_emergency_control.v0",
    pilotEmergencyControlId: "0x0000000000000000000000000000000000000000000000000000000000000000",
    chainId: input.chainId,
    contractAddress: normalizeAddress(input.contractAddress),
    operatorId: input.operatorId,
    action: input.action,
    targetSignerId: input.targetSignerId,
    reasonHash: input.reasonHash,
    issuedAtUnixMs: input.issuedAtUnixMs,
    expiresAtUnixMs: input.expiresAtUnixMs,
    nonce: input.nonce,
    pilotCap: input.pilotCap
  };
  document.pilotEmergencyControlId = pilotEmergencyControlId(document);
  return document;
}

function publicAccountMetadata(account) {
  const metadata = {
    signerId: account.signerId,
    signerKeyId: account.signerKeyId,
    signerRole: account.signerRole,
    signerRoleCode: account.signerRoleCode,
    publicKey: account.publicKey,
    label: account.label,
    createdAtUnixMs: account.createdAtUnixMs,
    active: account.active !== false
  };
  if (account.publicKeyHash) {
    metadata.publicKeyHash = account.publicKeyHash;
  }
  return metadata;
}

function requiredEnv(env, name) {
  const value = env[name];
  if (value === undefined || value === null || value === "") {
    throw new Error(`missing ${name}`);
  }
  return value;
}

function parsePilotChainId(value) {
  const chainId = Number(value);
  if (!Number.isSafeInteger(chainId) || !SUPPORTED_PILOT_CHAIN_IDS.has(chainId)) {
    throw new Error(`unsupported pilot chain id: ${value}`);
  }
  return chainId;
}

function normalizeAddress(value) {
  if (typeof value !== "string" || !/^0x[0-9a-fA-F]{40}$/.test(value)) {
    throw new Error(`invalid address: ${value}`);
  }
  return value.toLowerCase();
}

function assertPilotOperatorConfig(config) {
  if (config.schema !== PILOT_OPERATOR_CONFIG_SCHEMA) {
    throw new Error("invalid pilot operator config schema");
  }
  if (!SUPPORTED_PILOT_CHAIN_IDS.has(config.chainId)) {
    throw new Error(`unsupported pilot chain id: ${config.chainId}`);
  }
  if (!isHex32(config.operatorId)) {
    throw new Error("invalid pilot operator id");
  }
  if (!isUintString(config.createdAtUnixMs)) {
    throw new Error("invalid pilot config createdAtUnixMs");
  }
  assertPilotCap(config.pilotCap);
  for (const [name, value] of Object.entries(config.localPaths ?? {})) {
    if (typeof value !== "string" || value.length === 0) {
      throw new Error(`invalid pilot local path: ${name}`);
    }
  }
  if (!Array.isArray(config.nextCommands) || config.nextCommands.length < 5) {
    throw new Error("pilot config must include deploy, observe, credit, release, and verify next commands");
  }
  if (config.productionReady !== false) {
    throw new Error("pilot operator config must not claim production readiness");
  }
  if (config.chainId === BASE_MAINNET_CHAIN_ID) {
    assertBaseMainnetCanaryCap(config.pilotCap);
  }
}

function assertPilotCap(cap) {
  if (!cap || typeof cap !== "object") {
    throw new Error("missing pilot cap");
  }
  if (!isHex32(cap.capId)) {
    throw new Error("invalid pilot cap id");
  }
  if (!isHex32(cap.assetId)) {
    throw new Error("invalid pilot cap asset id");
  }
  for (const field of ["maxAmount", "usedAmount", "windowStartsAtUnixMs", "windowEndsAtUnixMs"]) {
    if (!isUintString(cap[field])) {
      throw new Error(`invalid pilot cap ${field}`);
    }
  }
  const maxAmount = BigInt(cap.maxAmount);
  const usedAmount = BigInt(cap.usedAmount);
  const windowStartsAtUnixMs = BigInt(cap.windowStartsAtUnixMs);
  const windowEndsAtUnixMs = BigInt(cap.windowEndsAtUnixMs);
  if (maxAmount <= 0n) {
    throw new Error("pilot cap maxAmount must be positive");
  }
  if (usedAmount < 0n || usedAmount > maxAmount) {
    throw new Error("pilot cap usedAmount must be between zero and maxAmount");
  }
  if (windowEndsAtUnixMs <= windowStartsAtUnixMs) {
    throw new Error("pilot cap window must end after it starts");
  }
  if (typeof cap.unit !== "string" || cap.unit.length === 0) {
    throw new Error("pilot cap unit is required");
  }
  if (cap.realValuePilot !== true || cap.productionReady !== false) {
    throw new Error("pilot cap must be real-value pilot only and not production ready");
  }
}

function assertBaseMainnetCanaryCap(cap) {
  if (cap.unit !== "USDC-6") {
    throw new Error("Base mainnet pilot cap unit must be USDC-6");
  }
  if (BigInt(cap.maxAmount) > BASE_MAINNET_MAX_USDC6_CAP) {
    throw new Error("Base mainnet pilot cap must not exceed 25 USD");
  }
}

function isHex32(value) {
  return typeof value === "string" && /^0x[0-9a-fA-F]{64}$/.test(value);
}

function isUintString(value) {
  return typeof value === "string" && /^[0-9]+$/.test(value);
}

function assertOperatorConfigHasNoRuntimeSecrets(config) {
  const serialized = JSON.stringify(config);
  if (
    /privateKey|private_key|seedPhrase|seed phrase|mnemonic|ciphertext|authTag|password|rpc[-_]?credential|rpc[-_]?url|api[-_]?key|webhook/i.test(serialized)
  ) {
    throw new Error("pilot operator config contains signing-secret material");
  }
}
