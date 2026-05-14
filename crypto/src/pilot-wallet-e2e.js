#!/usr/bin/env node
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";

import Ajv2020 from "ajv/dist/2020.js";
import addFormats from "ajv-formats";

import {
  createEncryptedTestVault,
  exportVaultPublicMetadata,
  signLocalTransactionWithVault
} from "./wallet.js";
import {
  buildPilotBridgeCreditAckDocument,
  buildPilotEmergencyControlDocument,
  buildPilotReleaseEvidenceDocument,
  buildPilotWithdrawalIntentDocument,
  createPilotOperatorConfigFromEnv,
  exportPilotPublicMetadata
} from "./pilot-operator.js";
import {
  assertPublicPilotMetadataContainsNoSecrets,
  pilotEnvelopeReplayKey,
  validatePilotOperatorEnvelope
} from "./pilot-envelope-validation.js";
import { keccakUtf8 } from "./hashes.js";

const root = resolve(import.meta.dirname, "..");
const repoRoot = resolve(root, "..");
const outDir = resolve(root, "out", "pilot-wallet-e2e");
mkdirSync(outDir, { recursive: true });

const issuedAtUnixMs = "1778702400000";
const expiresAtUnixMs = "1778706000000";
const password = "pilot-wallet-e2e";

const vault = createEncryptedTestVault({
  password,
  label: "real-value-pilot-operator",
  signerRole: "operator",
  privateKey: "0x0000000000000000000000000000000000000000000000000000000000000001",
  createdAtUnixMs: issuedAtUnixMs
});
const operatorAccount = vault.publicAccounts[0];

const env = {
  FLOWCHAIN_PILOT_CHAIN_ID: "84532",
  FLOWCHAIN_PILOT_CONTRACT_ADDRESS: "0x1111111111111111111111111111111111111111",
  FLOWCHAIN_PILOT_OPERATOR_ID: operatorAccount.signerId,
  FLOWCHAIN_PILOT_CAP_ID: keccakUtf8("pilot-cap:real-value-capped:2026-05-13"),
  FLOWCHAIN_PILOT_CAP_ASSET_ID: keccakUtf8("asset:usdc:base-sepolia"),
  FLOWCHAIN_PILOT_CAP_MAX_AMOUNT: "25000000",
  FLOWCHAIN_PILOT_CAP_USED_AMOUNT: "5000000",
  FLOWCHAIN_PILOT_CAP_UNIT: "USDC-6",
  FLOWCHAIN_PILOT_CAP_WINDOW_START_UNIX_MS: "1778702400000",
  FLOWCHAIN_PILOT_CAP_WINDOW_END_UNIX_MS: "1778788800000",
  FLOWCHAIN_PILOT_CONFIG_PATH: "devnet/local/pilot-wallet/operator-config.local.json",
  FLOWCHAIN_PILOT_VAULT_PATH: "devnet/local/pilot-wallet/operator-vault.json",
  FLOWCHAIN_PILOT_PUBLIC_METADATA_PATH: "devnet/local/pilot-wallet/operator-public-metadata.json",
  FLOWCHAIN_PILOT_RPC_URL: "https://example.invalid/secret-token",
  FLOWCHAIN_PILOT_API_KEY: "not-written",
  FLOWCHAIN_PILOT_WEBHOOK_URL: "https://discord.com/api/webhooks/not-written"
};

const config = createPilotOperatorConfigFromEnv({ env, createdAtUnixMs: issuedAtUnixMs });
const configPath = resolve(outDir, "operator-config.local.json");
writeJson(configPath, config);
assertNoLeakedEnvValues(config, env);

const publicMetadata = exportPilotPublicMetadata({
  config,
  walletMetadata: exportVaultPublicMetadata(vault)
});
assertPublicPilotMetadataContainsNoSecrets(publicMetadata);
assertNoLeakedEnvValues(publicMetadata, env);

const ajv = new Ajv2020({ allErrors: true, strict: false });
addFormats(ajv);
const schemaValidators = new Map();
validateSchema("real-value-pilot-operator-config.schema.json", config, "pilot config");
validateSchema("real-value-pilot-public-metadata.schema.json", publicMetadata, "pilot public metadata");

const common = {
  contractAddress: config.contractAddress,
  operatorId: config.operatorId,
  pilotCap: config.pilotCap,
  issuedAtUnixMs,
  expiresAtUnixMs
};
const creditId = keccakUtf8("pilot-credit");
const depositId = keccakUtf8("pilot-deposit");
const flowchainAccount = operatorAccount.signerId;
const token = "0x3333333333333333333333333333333333333333";
const recipient = "0x4444444444444444444444444444444444444444";

const bridgeCreditAck = buildPilotBridgeCreditAckDocument({
  ...common,
  chainId: config.chainId,
  creditId,
  depositId,
  accountId: flowchainAccount,
  assetId: config.pilotCap.assetId,
  amount: "5000000",
  acknowledgedAtBlockNumber: "10",
  accountNonce: "1"
});
const withdrawalIntent = buildPilotWithdrawalIntentDocument({
  ...common,
  sourceChainId: config.chainId,
  destinationChainId: config.chainId,
  creditId,
  depositId,
  token,
  amount: "3000000",
  flowchainAccount,
  baseRecipient: recipient,
  requestedAt: "2026-05-13T23:00:00.000Z",
  accountNonce: "2"
});
const releaseEvidence = buildPilotReleaseEvidenceDocument({
  ...common,
  chainId: config.chainId,
  withdrawalIntentId: withdrawalIntent.pilotWithdrawalIntentId,
  releaseTxHash: keccakUtf8("pilot-release-tx"),
  releaseLogIndex: 0,
  token,
  amount: "3000000",
  recipient,
  releasedAtBlockNumber: "12",
  releasedAtUnixMs: "1778703000000",
  evidenceHash: keccakUtf8("pilot-release-evidence")
});
const pauseMessage = buildPilotEmergencyControlDocument({
  ...common,
  chainId: config.chainId,
  action: "pause",
  targetSignerId: operatorAccount.signerId,
  reasonHash: keccakUtf8("operator emergency pause"),
  nonce: keccakUtf8("pilot-emergency-pause")
});
const revokeMessage = buildPilotEmergencyControlDocument({
  ...common,
  chainId: config.chainId,
  action: "revoke",
  targetSignerId: operatorAccount.signerId,
  reasonHash: keccakUtf8("operator emergency revoke"),
  nonce: keccakUtf8("pilot-emergency-revoke")
});

const documents = [
  bridgeCreditAck,
  withdrawalIntent,
  releaseEvidence,
  pauseMessage,
  revokeMessage
];
for (const [index, document] of documents.entries()) {
  validateSchema("real-value-pilot-message.schema.json", document, document.schema);
  const envelope = await signLocalTransactionWithVault({
    vault,
    password,
    signerKeyId: operatorAccount.signerKeyId,
    document,
    chainId: config.chainId,
    nonce: String(index + 1),
    issuedAtUnixMs
  });
  assert.deepEqual(
    validatePilotOperatorEnvelope({
      document,
      envelope,
      context: {
        expectedChainId: config.chainId,
        expectedContractAddress: config.contractAddress,
        expectedOperatorId: config.operatorId,
        expectedNonce: String(index + 1),
        nowUnixMs: issuedAtUnixMs
      }
    }),
    { valid: true, errors: [] },
    document.schema
  );
}

const envelope = await signLocalTransactionWithVault({
  vault,
  password,
  signerKeyId: operatorAccount.signerKeyId,
  document: releaseEvidence,
  chainId: config.chainId,
  nonce: "99",
  issuedAtUnixMs
});
const negativeCases = [
  {
    name: "wrong chain id",
    document: releaseEvidence,
    envelope,
    context: { expectedChainId: "8453" },
    error: "wrong-chain-id"
  },
  {
    name: "wrong contract address",
    document: releaseEvidence,
    envelope,
    context: { expectedContractAddress: "0x2222222222222222222222222222222222222222" },
    error: "wrong-contract-address"
  },
  {
    name: "wrong operator",
    document: releaseEvidence,
    envelope,
    context: { expectedOperatorId: keccakUtf8("wrong-operator") },
    error: "wrong-operator"
  },
  {
    name: "mutated payload",
    document: { ...releaseEvidence, amount: "1" },
    envelope,
    context: {},
    error: "bad-payload-hash"
  },
  {
    name: "replay nonce",
    document: releaseEvidence,
    envelope,
    context: { seenNonces: new Set([pilotEnvelopeReplayKey(envelope)]) },
    error: "replay"
  },
  {
    name: "expired message",
    document: releaseEvidence,
    envelope,
    context: { nowUnixMs: "1778709600000" },
    error: "expired-message"
  },
  {
    name: "missing cap fields",
    document: withoutField(releaseEvidence, "pilotCap"),
    envelope,
    context: {},
    error: "missing-cap-fields"
  }
];

for (const testCase of negativeCases) {
  const result = validatePilotOperatorEnvelope({
    document: testCase.document,
    envelope: testCase.envelope,
    context: {
      expectedChainId: config.chainId,
      expectedContractAddress: config.contractAddress,
      expectedOperatorId: config.operatorId,
      ...testCase.context
    }
  });
  assert.equal(result.valid, false, testCase.name);
  assert.ok(result.errors.includes(testCase.error), `${testCase.name}: ${result.errors.join(", ")}`);
}

const validationSource = readFileSync(resolve(root, "src", "pilot-envelope-validation.js"), "utf8");
assert.doesNotMatch(validationSource, /from "\.\/wallet\.js"/);
assert.doesNotMatch(validationSource, /createEncryptedTestVault|unlockEncryptedTestVault|signLocalTransactionWithVault/);

const nextCommandsOutput = execFileSync(
  process.execPath,
  [resolve(root, "src", "pilot-wallet-cli.js"), "next-commands", "--config", configPath],
  { encoding: "utf8" }
);
assert.match(nextCommandsOutput, /deploy:base-sepolia:plan/);
assert.match(nextCommandsOutput, /flowchain-wallet-pilot-observe\.ps1/);
assert.match(nextCommandsOutput, /bridge:local-credit:smoke/);
assert.match(nextCommandsOutput, /wallet:pilot-sign/);
assert.match(nextCommandsOutput, /wallet:pilot-verify/);

writeJson(resolve(outDir, "public-metadata.json"), publicMetadata);
writeJson(resolve(outDir, "release-evidence.json"), releaseEvidence);
writeJson(resolve(outDir, "release-envelope.json"), envelope);

console.log(
  `FLOWCHAIN_PILOT_WALLET_E2E_OK documents=${documents.length} envelopes=${documents.length} negativeCases=${negativeCases.length}`
);

function validateSchema(name, document, label) {
  let validate = schemaValidators.get(name);
  if (!validate) {
    const schema = readJson(resolve(repoRoot, "schemas", "flowmemory", name));
    validate = ajv.compile(schema);
    schemaValidators.set(name, validate);
  }
  assert.equal(validate(document), true, `${label}: ${ajv.errorsText(validate.errors)}`);
}

function assertNoLeakedEnvValues(value, envValues) {
  const serialized = JSON.stringify(value);
  for (const envName of ["FLOWCHAIN_PILOT_RPC_URL", "FLOWCHAIN_PILOT_API_KEY", "FLOWCHAIN_PILOT_WEBHOOK_URL"]) {
    assert.doesNotMatch(serialized, new RegExp(escapeRegExp(envValues[envName]), "i"), envName);
  }
}

function withoutField(document, field) {
  const copy = structuredClone(document);
  delete copy[field];
  return copy;
}

function readJson(path) {
  return JSON.parse(readFileSync(path, "utf8"));
}

function writeJson(path, value) {
  writeFileSync(path, `${JSON.stringify(value, null, 2)}\n`);
}

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}
